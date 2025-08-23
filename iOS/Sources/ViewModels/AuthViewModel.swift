//
//  AuthViewModel.swift
//  Mervyn Talks
//
//  Handles required sign-in (Apple first). Links to anonymous user to preserve UID/credits.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: NSObject, ObservableObject {
    static let shared = AuthViewModel()

    @Published private(set) var isSignedIn: Bool = Auth.auth().currentUser != nil && Auth.auth().currentUser?.isAnonymous == false
    @Published var lastError: String?

    private var currentNonce: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    override init() {
        super.init()
        setupAuthStateListener()
        Task { await ensureAnonymousIfNeeded() }
    }
    
    deinit {
        cleanupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isSignedIn = user != nil && user?.isAnonymous == false
                if user != nil { 
                    await CreditsManager.shared.syncWithCloud() 
                }
            }
        }
    }
    
    private func cleanupAuthStateListener() {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            authStateHandle = nil
        }
    }

    func ensureAnonymousIfNeeded() async {
        if Auth.auth().currentUser == nil {
            do { _ = try await Auth.auth().signInAnonymously() } catch { self.lastError = error.localizedDescription }
        }
    }

    // MARK: - Sign in with Apple
    func startSignInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // MARK: - SignInWithAppleButton Support
    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            // Handle success directly without creating a controller
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                processAppleSignIn(credential: appleIDCredential)
            } else {
                self.lastError = "Invalid Apple ID credential"
            }
        case .failure(let error):
            self.lastError = error.localizedDescription
        }
    }
    
    private func processAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        guard let nonce = currentNonce, 
              let appleToken = credential.identityToken, 
              let idTokenString = String(data: appleToken, encoding: .utf8) else {
            self.lastError = "Apple sign-in failed"
            return
        }
        
        let firebaseCredential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let authResult: AuthDataResult
                if let user = Auth.auth().currentUser, user.isAnonymous {
                    authResult = try await user.link(with: firebaseCredential)
                } else {
                    authResult = try await Auth.auth().signIn(with: firebaseCredential)
                }
                
                // Create user profile in Firestore for admin dashboard visibility
                await self.createUserProfile(user: authResult.user, appleCredential: credential)
                
                // Starter grant after first sign-in
                await CreditsManager.shared.grantStarterIfNeededWithDeviceThrottle()
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess { fatalError("Unable to generate nonce. SecRandomCopyBytes failed") }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count { result.append(charset[Int(random)]) ; remainingLength -= 1 }
            }
        }
        return result
    }
    
    // MARK: - User Profile Management
    
    private func createUserProfile(user: User, appleCredential: ASAuthorizationAppleIDCredential) async {
        let db = Firestore.firestore()
        let uid = user.uid
        
        do {
            // Check if user profile already exists
            let userRef = db.collection("users").document(uid)
            let doc = try await userRef.getDocument()
            
            if doc.exists {
                // User profile exists, just update last sign-in time
                try await userRef.updateData([
                    "lastSignInTime": FieldValue.serverTimestamp()
                ])
                print("👤 [AuthViewModel] Updated existing user profile for: \(user.email ?? uid)")
            } else {
                // Create new user profile
                let userData: [String: Any] = [
                    "uid": uid,
                    "email": user.email ?? "",
                    "displayName": user.displayName ?? appleCredential.fullName?.formatted() ?? "",
                    "createdAt": FieldValue.serverTimestamp(),
                    "lastSignInTime": FieldValue.serverTimestamp(),
                    "provider": "apple.com",
                    "totalMinutesUsed": 0.0,
                    "sessionsCount": 0,
                    "isBetaUser": false,
                    "isActive": true
                ]
                
                try await userRef.setData(userData)
                print("👤 [AuthViewModel] Created new user profile for: \(user.email ?? uid)")
            }
        } catch {
            print("❌ [AuthViewModel] Failed to create/update user profile: \(error.localizedDescription)")
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        guard let nonce = currentNonce, let appleToken = appleIDCredential.identityToken, let idTokenString = String(data: appleToken, encoding: .utf8) else {
            self.lastError = "Apple sign-in failed"
            return
        }
        let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: idTokenString, rawNonce: nonce)

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let authResult: AuthDataResult
                if let user = Auth.auth().currentUser, user.isAnonymous {
                    authResult = try await user.link(with: credential)
                } else {
                    authResult = try await Auth.auth().signIn(with: credential)
                }
                
                // Create user profile in Firestore for admin dashboard visibility
                await self.createUserProfile(user: authResult.user, appleCredential: appleIDCredential)
                
                // Starter grant after first sign-in
                await CreditsManager.shared.grantStarterIfNeededWithDeviceThrottle()
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        self.lastError = error.localizedDescription
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return window
        }
        // Fallback to any visible window
        if let anyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first {
            return anyWindow
        }
        return ASPresentationAnchor()
    }
}


