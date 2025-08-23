import Foundation
import Security
import LocalAuthentication
import CryptoKit
import AuthenticationServices

/// OAuth 2.0 Manager with PKCE (Proof Key for Code Exchange) implementation
/// Provides enterprise-grade authentication with secure token management
@MainActor
public final class OAuth2Manager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: OAuth2User?
    @Published public var isLoading: Bool = false
    
    // MARK: - Private Properties
    private let configuration: OAuth2Configuration
    private let tokenStore: SecureTokenStore
    private var currentAuthSession: ASWebAuthenticationSession?
    private let networkManager: NetworkManager
    
    // MARK: - PKCE Properties
    private var codeVerifier: String = ""
    private var codeChallenge: String = ""
    private var state: String = ""
    
    // MARK: - Initialization
    public init(configuration: OAuth2Configuration) {
        self.configuration = configuration
        self.tokenStore = SecureTokenStore()
        self.networkManager = NetworkManager()
        super.init()
        
        Task {
            await checkAuthenticationStatus()
        }
    }
    
    // MARK: - Public Authentication Methods
    
    /// Initiates OAuth 2.0 authentication flow with PKCE
    /// - Parameter provider: The OAuth provider to authenticate with
    public func authenticate(with provider: OAuth2Provider) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Generate PKCE parameters
            try generatePKCEParameters()
            
            // Build authorization URL
            let authURL = try buildAuthorizationURL(for: provider)
            
            // Start authentication session
            let authCode = try await performAuthenticationSession(url: authURL, provider: provider)
            
            // Exchange authorization code for tokens
            let tokens = try await exchangeCodeForTokens(code: authCode, provider: provider)
            
            // Fetch user information
            let user = try await fetchUserInfo(accessToken: tokens.accessToken, provider: provider)
            
            // Store tokens securely
            try await tokenStore.storeTokens(tokens, for: user.id, provider: provider.rawValue)
            
            // Update state
            self.currentUser = user
            self.isAuthenticated = true
            
            // Log successful authentication
            SecurityLogger.shared.logAuthenticationSuccess(provider: provider.rawValue, userId: user.id)
            
        } catch {
            SecurityLogger.shared.logAuthenticationFailure(provider: provider.rawValue, error: error)
            throw error
        }
    }
    
    /// Refreshes the current access token
    public func refreshToken() async throws {
        guard let currentUser = currentUser,
              let provider = OAuth2Provider(rawValue: currentUser.provider) else {
            throw OAuth2Error.noActiveSession
        }
        
        do {
            // Retrieve stored tokens
            let storedTokens = try await tokenStore.retrieveTokens(for: currentUser.id, provider: provider.rawValue)
            
            guard let refreshToken = storedTokens.refreshToken else {
                throw OAuth2Error.noRefreshToken
            }
            
            // Refresh tokens
            let newTokens = try await performTokenRefresh(refreshToken: refreshToken, provider: provider)
            
            // Store new tokens
            try await tokenStore.storeTokens(newTokens, for: currentUser.id, provider: provider.rawValue)
            
            SecurityLogger.shared.logTokenRefresh(userId: currentUser.id, provider: provider.rawValue)
            
        } catch {
            SecurityLogger.shared.logTokenRefreshFailure(userId: currentUser?.id ?? "unknown", error: error)
            
            // If refresh fails, logout user
            await logout()
            throw error
        }
    }
    
    /// Logs out the current user and cleans up tokens
    public func logout() async {
        defer {
            currentUser = nil
            isAuthenticated = false
            SecurityLogger.shared.logLogout()
        }
        
        guard let user = currentUser else { return }
        
        do {
            // Revoke tokens on server if possible
            if let provider = OAuth2Provider(rawValue: user.provider) {
                try? await revokeTokens(for: user.id, provider: provider)
            }
            
            // Clear stored tokens
            try await tokenStore.clearTokens(for: user.id, provider: user.provider)
            
        } catch {
            SecurityLogger.shared.logError("Failed to clear tokens during logout", error: error)
        }
    }
    
    /// Gets a valid access token, refreshing if necessary
    public func getValidAccessToken() async throws -> String {
        guard let currentUser = currentUser,
              let provider = OAuth2Provider(rawValue: currentUser.provider) else {
            throw OAuth2Error.noActiveSession
        }
        
        let tokens = try await tokenStore.retrieveTokens(for: currentUser.id, provider: provider.rawValue)
        
        // Check if token is expired
        if tokens.isExpired {
            try await refreshToken()
            let refreshedTokens = try await tokenStore.retrieveTokens(for: currentUser.id, provider: provider.rawValue)
            return refreshedTokens.accessToken
        }
        
        return tokens.accessToken
    }
    
    // MARK: - Private Methods
    
    /// Checks current authentication status on app launch
    private func checkAuthenticationStatus() async {
        // Check for stored tokens and validate them
        // Implementation would check keychain for existing valid tokens
        // For now, set to false - would be implemented based on stored tokens
        isAuthenticated = false
    }
    
    /// Generates PKCE code verifier and challenge
    private func generatePKCEParameters() throws {
        // Generate code verifier (43-128 characters)
        let codeVerifierData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        codeVerifier = codeVerifierData.base64URLEncodedString()
        
        // Generate code challenge (SHA256 hash of verifier)
        let challengeData = Data(SHA256.hash(data: codeVerifierData))
        codeChallenge = challengeData.base64URLEncodedString()
        
        // Generate state parameter
        let stateData = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        state = stateData.base64URLEncodedString()
    }
    
    /// Builds authorization URL with PKCE parameters
    private func buildAuthorizationURL(for provider: OAuth2Provider) throws -> URL {
        let config = configuration.providerConfig(for: provider)
        
        var components = URLComponents(string: config.authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientId),
            URLQueryItem(name: "redirect_uri", value: config.redirectURI),
            URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        // Add provider-specific parameters
        if provider == .apple {
            components.queryItems?.append(URLQueryItem(name: "response_mode", value: "form_post"))
        }
        
        guard let url = components.url else {
            throw OAuth2Error.invalidAuthorizationURL
        }
        
        return url
    }
    
    /// Performs the authentication session using ASWebAuthenticationSession
    private func performAuthenticationSession(url: URL, provider: OAuth2Provider) async throws -> String {
        let config = configuration.providerConfig(for: provider)
        
        return try await withCheckedThrowingContinuation { continuation in
            currentAuthSession = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: config.callbackURLScheme
            ) { callbackURL, error in
                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        continuation.resume(throwing: OAuth2Error.userCancelled)
                    } else {
                        continuation.resume(throwing: OAuth2Error.authenticationFailed(error))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: OAuth2Error.invalidCallback)
                    return
                }
                
                do {
                    let authCode = try self.extractAuthorizationCode(from: callbackURL)
                    continuation.resume(returning: authCode)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            currentAuthSession?.presentationContextProvider = self
            currentAuthSession?.prefersEphemeralWebBrowserSession = true
            currentAuthSession?.start()
        }
    }
    
    /// Extracts authorization code from callback URL
    private func extractAuthorizationCode(from url: URL) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw OAuth2Error.invalidCallback
        }
        
        // Check for error in callback
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            throw OAuth2Error.serverError(error)
        }
        
        // Verify state parameter
        if let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
           returnedState != state {
            throw OAuth2Error.stateMismatch
        }
        
        // Extract authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
            throw OAuth2Error.noAuthorizationCode
        }
        
        return code
    }
    
    /// Exchanges authorization code for access tokens
    private func exchangeCodeForTokens(code: String, provider: OAuth2Provider) async throws -> OAuth2Tokens {
        let config = configuration.providerConfig(for: provider)
        
        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "authorization_code",
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": config.redirectURI,
            "code_verifier": codeVerifier
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuth2Error.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OAuth2Error.tokenExchangeFailed(httpResponse.statusCode)
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return OAuth2Tokens(from: tokenResponse)
    }
    
    /// Fetches user information using access token
    private func fetchUserInfo(accessToken: String, provider: OAuth2Provider) async throws -> OAuth2User {
        let config = configuration.providerConfig(for: provider)
        
        var request = URLRequest(url: URL(string: config.userInfoEndpoint)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuth2Error.userInfoFetchFailed
        }
        
        let userInfo = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        return OAuth2User(from: userInfo, provider: provider.rawValue)
    }
    
    /// Performs token refresh
    private func performTokenRefresh(refreshToken: String, provider: OAuth2Provider) async throws -> OAuth2Tokens {
        let config = configuration.providerConfig(for: provider)
        
        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "grant_type": "refresh_token",
            "client_id": config.clientId,
            "refresh_token": refreshToken
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuth2Error.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OAuth2Error.tokenRefreshFailed(httpResponse.statusCode)
        }
        
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return OAuth2Tokens(from: tokenResponse)
    }
    
    /// Revokes tokens on the server
    private func revokeTokens(for userId: String, provider: OAuth2Provider) async throws {
        let config = configuration.providerConfig(for: provider)
        
        guard !config.revokeEndpoint.isEmpty else {
            return // Provider doesn't support token revocation
        }
        
        let tokens = try await tokenStore.retrieveTokens(for: userId, provider: provider.rawValue)
        
        var request = URLRequest(url: URL(string: config.revokeEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let parameters = [
            "client_id": config.clientId,
            "token": tokens.accessToken
        ]
        
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension OAuth2Manager: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - NetworkManager
private class NetworkManager {
    func performRequest<T: Codable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OAuth2Error.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw OAuth2Error.networkError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Data Extensions
private extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Response Models
private struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
    }
}

private struct UserInfoResponse: Codable {
    let id: String
    let email: String?
    let name: String?
    let picture: String?
    let verified: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, picture, verified
    }
}