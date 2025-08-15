//
//  AuthViewModel.swift
//  Mervyn Talks
//
//  Handles required sign-in (Apple first). Links to anonymous user to preserve UID/credits.
//

import Foundation
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthViewModel: NSObject, ObservableObject {
    static let shared = AuthViewModel()

    @Published private(set) var isSignedIn: Bool = Auth.auth().currentUser != nil && Auth.auth().currentUser?.isAnonymous == false
    @Published var lastError: String?

    private var currentNonce: String?

    override init() {
        super.init()
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isSignedIn = user != nil && user?.isAnonymous == false
                if let _ = user { await CreditsManager.shared.syncWithCloud() }
            }
        }
        Task { await ensureAnonymousIfNeeded() }
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
            authorizationController(controller: ASAuthorizationController(authorizationRequests: []), didCompleteWithAuthorization: authorization)
        case .failure(let error):
            authorizationController(controller: ASAuthorizationController(authorizationRequests: []), didCompleteWithError: error)
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

        Task {
            do {
                if let user = Auth.auth().currentUser, user.isAnonymous {
                    _ = try await user.link(with: credential)
                } else {
                    _ = try await Auth.auth().signIn(with: credential)
                }
                // Starter grant after first sign-in
                await CreditsManager.shared.grantStarterIfNeededWithDeviceThrottle()
            } catch {
                await MainActor.run { self.lastError = error.localizedDescription }
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


