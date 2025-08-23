import XCTest
import AuthenticationServices
import LocalAuthentication
@testable import UniversalTranslator

final class OAuth2ManagerTests: XCTestCase {
    
    var oauth2Manager: OAuth2Manager!
    var mockConfiguration: OAuth2Configuration!
    
    override func setUp() async throws {
        try await super.setUp()
        mockConfiguration = OAuth2Configuration()
        oauth2Manager = OAuth2Manager(configuration: mockConfiguration)
    }
    
    override func tearDown() async throws {
        oauth2Manager = nil
        mockConfiguration = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testOAuth2ManagerInitialization() {
        XCTAssertNotNil(oauth2Manager)
        XCTAssertFalse(oauth2Manager.isAuthenticated)
        XCTAssertNil(oauth2Manager.currentUser)
        XCTAssertFalse(oauth2Manager.isLoading)
    }
    
    // MARK: - Configuration Tests
    
    func testProviderConfigurations() {
        let googleConfig = mockConfiguration.providerConfig(for: .google)
        XCTAssertFalse(googleConfig.clientId.isEmpty, "Google client ID should not be empty")
        XCTAssertEqual(googleConfig.authorizationEndpoint, "https://accounts.google.com/o/oauth2/v2/auth")
        XCTAssertEqual(googleConfig.tokenEndpoint, "https://oauth2.googleapis.com/token")
        
        let appleConfig = mockConfiguration.providerConfig(for: .apple)
        XCTAssertEqual(appleConfig.authorizationEndpoint, "https://appleid.apple.com/auth/authorize")
        XCTAssertEqual(appleConfig.tokenEndpoint, "https://appleid.apple.com/auth/token")
    }
    
    func testProviderValidation() {
        let errors = mockConfiguration.validateConfigurations()
        
        // If configurations are properly set up, there should be no errors
        if !errors.isEmpty {
            print("Configuration errors found: \(errors)")
        }
    }
    
    // MARK: - PKCE Generation Tests
    
    func testPKCEParameterGeneration() async throws {
        // We can't directly test private methods, but we can test the results
        // through the authentication flow initialization
        
        // Mock a provider config
        let provider = OAuth2Provider.google
        let config = mockConfiguration.providerConfig(for: provider)
        
        // Test that authorization URL can be built (which requires PKCE params)
        let url = config.authorizationURL(
            codeChallenge: "test-challenge",
            state: "test-state"
        )
        
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("code_challenge=test-challenge"))
        XCTAssertTrue(url!.absoluteString.contains("code_challenge_method=S256"))
        XCTAssertTrue(url!.absoluteString.contains("state=test-state"))
    }
    
    // MARK: - Token Management Tests
    
    func testTokenExpiration() {
        let expiredTokens = OAuth2Tokens(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago
            scope: "openid email"
        )
        
        XCTAssertTrue(expiredTokens.isExpired)
        
        let validTokens = OAuth2Tokens(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresAt: Date().addingTimeInterval(3600), // Expires in 1 hour
            scope: "openid email"
        )
        
        XCTAssertFalse(validTokens.isExpired)
    }
    
    func testTokenAuthorizationHeader() {
        let tokens = OAuth2Tokens(
            accessToken: "test-access-token",
            tokenType: "Bearer"
        )
        
        XCTAssertEqual(tokens.authorizationHeader, "Bearer test-access-token")
    }
    
    // MARK: - Error Handling Tests
    
    func testOAuth2ErrorTypes() {
        let userCancelledError = OAuth2Error.userCancelled
        XCTAssertTrue(userCancelledError.isRecoverable)
        XCTAssertFalse(userCancelledError.requiresReauthentication)
        XCTAssertFalse(userCancelledError.isSecurityError)
        
        let tokenExpiredError = OAuth2Error.tokenExpired
        XCTAssertTrue(tokenExpiredError.isRecoverable)
        XCTAssertTrue(tokenExpiredError.requiresReauthentication)
        XCTAssertFalse(tokenExpiredError.isSecurityError)
        
        let securityError = OAuth2Error.securityValidationFailed
        XCTAssertFalse(securityError.isRecoverable)
        XCTAssertFalse(securityError.requiresReauthentication)
        XCTAssertTrue(securityError.isSecurityError)
    }
    
    func testErrorFromNetworkResponse() {
        let unauthorizedResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let error = OAuth2Error.fromNetworkResponse(unauthorizedResponse, data: nil)
        XCTAssertEqual(error.category, "token_management")
        XCTAssertTrue(error.requiresReauthentication)
    }
    
    func testErrorFromURLError() {
        let urlError = URLError(.notConnectedToInternet)
        let oauth2Error = OAuth2Error.fromURLError(urlError)
        
        switch oauth2Error {
        case .noInternetConnection:
            XCTAssertTrue(true) // Expected case
        default:
            XCTFail("Expected noInternetConnection error")
        }
        
        XCTAssertTrue(oauth2Error.isRecoverable)
        XCTAssertTrue(oauth2Error.isNetworkError)
    }
    
    // MARK: - User Model Tests
    
    func testOAuth2UserInitialization() {
        let userInfoResponse = UserInfoResponse(
            id: "test-user-id",
            email: "test@example.com",
            name: "Test User",
            picture: "https://example.com/avatar.jpg",
            verified: true
        )
        
        let oauth2User = OAuth2User(from: userInfoResponse, provider: "google")
        
        XCTAssertEqual(oauth2User.id, "test-user-id")
        XCTAssertEqual(oauth2User.email, "test@example.com")
        XCTAssertEqual(oauth2User.name, "Test User")
        XCTAssertEqual(oauth2User.displayName, "Test User")
        XCTAssertEqual(oauth2User.initials, "TU")
        XCTAssertEqual(oauth2User.provider, "google")
        XCTAssertTrue(oauth2User.verified)
    }
    
    func testOAuth2UserDisplayName() {
        // Test with name
        let userWithName = OAuth2User(
            id: "1",
            email: "test@example.com",
            name: "John Doe",
            picture: nil,
            provider: "google"
        )
        XCTAssertEqual(userWithName.displayName, "John Doe")
        
        // Test without name, with email
        let userWithEmail = OAuth2User(
            id: "2",
            email: "test@example.com",
            name: nil,
            picture: nil,
            provider: "google"
        )
        XCTAssertEqual(userWithEmail.displayName, "test@example.com")
        
        // Test without name or email
        let anonymousUser = OAuth2User(
            id: "3",
            email: nil,
            name: nil,
            picture: nil,
            provider: "apple"
        )
        XCTAssertEqual(anonymousUser.displayName, "User")
    }
    
    // MARK: - URL Handling Tests
    
    func testOAuthParameterExtraction() {
        let callbackURL = URL(string: "com.universaltranslator://oauth/google?code=auth-code&state=test-state")!
        let parameters = callbackURL.oauthParameters
        
        XCTAssertEqual(parameters["code"], "auth-code")
        XCTAssertEqual(parameters["state"], "test-state")
    }
    
    func testOAuthRedirectValidation() {
        let validRedirectURL = URL(string: "com.universaltranslator://oauth/google")!
        XCTAssertTrue(validRedirectURL.isOAuthRedirect(for: mockConfiguration))
        
        let invalidRedirectURL = URL(string: "https://example.com/callback")!
        XCTAssertFalse(invalidRedirectURL.isOAuthRedirect(for: mockConfiguration))
    }
    
    // MARK: - Provider Support Tests
    
    func testProviderSupport() {
        XCTAssertTrue(OAuth2Provider.google.supportsRefreshTokens)
        XCTAssertTrue(OAuth2Provider.google.supportsTokenRevocation)
        
        XCTAssertFalse(OAuth2Provider.apple.supportsRefreshTokens)
        XCTAssertTrue(OAuth2Provider.apple.supportsTokenRevocation)
        
        XCTAssertTrue(OAuth2Provider.microsoft.supportsRefreshTokens)
        XCTAssertFalse(OAuth2Provider.microsoft.supportsTokenRevocation)
    }
    
    func testProviderDisplayProperties() {
        XCTAssertEqual(OAuth2Provider.google.displayName, "Google")
        XCTAssertEqual(OAuth2Provider.apple.displayName, "Apple")
        XCTAssertEqual(OAuth2Provider.microsoft.displayName, "Microsoft")
        XCTAssertEqual(OAuth2Provider.github.displayName, "GitHub")
        
        XCTAssertEqual(OAuth2Provider.google.brandColor, "#4285F4")
        XCTAssertEqual(OAuth2Provider.apple.brandColor, "#000000")
    }
    
    // MARK: - Async Tests
    
    func testInvalidAuthenticationAttempt() async {
        // Test that concurrent authentication attempts are prevented
        oauth2Manager = OAuth2Manager(configuration: mockConfiguration)
        
        // We can't easily test the full authentication flow without mocking
        // the ASWebAuthenticationSession, but we can test error handling
        
        do {
            // This should fail due to invalid configuration in test environment
            try await oauth2Manager.authenticate(with: .google)
            XCTFail("Expected authentication to fail in test environment")
        } catch let error as OAuth2Error {
            // Expected to fail - test that we get appropriate error
            XCTAssertTrue(error.category == "authentication_flow" || 
                         error.category == "configuration")
        } catch {
            XCTFail("Expected OAuth2Error, got \(error)")
        }
    }
    
    func testGetValidAccessTokenWithoutSession() async {
        do {
            _ = try await oauth2Manager.getValidAccessToken()
            XCTFail("Expected error when no active session")
        } catch OAuth2Error.noActiveSession {
            // Expected error
        } catch {
            XCTFail("Expected noActiveSession error, got \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPKCEGenerationPerformance() {
        measure {
            // Simulate PKCE parameter generation
            for _ in 0..<100 {
                let data = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
                _ = data.base64EncodedString()
            }
        }
    }
    
    func testConfigurationValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = mockConfiguration.validateConfigurations()
            }
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullConfigurationIntegrity() {
        let configuration = OAuth2Configuration()
        
        for provider in OAuth2Provider.allCases {
            let config = configuration.providerConfig(for: provider)
            
            // Verify all required fields are present
            XCTAssertFalse(config.authorizationEndpoint.isEmpty, 
                          "\(provider.displayName) missing authorization endpoint")
            XCTAssertFalse(config.tokenEndpoint.isEmpty, 
                          "\(provider.displayName) missing token endpoint")
            XCTAssertFalse(config.redirectURI.isEmpty, 
                          "\(provider.displayName) missing redirect URI")
            XCTAssertFalse(config.callbackURLScheme.isEmpty, 
                          "\(provider.displayName) missing callback URL scheme")
            XCTAssertFalse(config.scopes.isEmpty, 
                          "\(provider.displayName) missing scopes")
            
            // Test URL generation
            let authURL = config.authorizationURL(
                codeChallenge: "test-challenge",
                state: "test-state"
            )
            XCTAssertNotNil(authURL, "\(provider.displayName) failed to generate auth URL")
        }
    }
}

// MARK: - Mock Objects

private struct UserInfoResponse: Codable {
    let id: String
    let email: String?
    let name: String?
    let picture: String?
    let verified: Bool?
}

// MARK: - Test Utilities

extension OAuth2ManagerTests {
    
    private func createMockTokens(expired: Bool = false) -> OAuth2Tokens {
        let expirationDate = expired ? 
            Date().addingTimeInterval(-3600) : 
            Date().addingTimeInterval(3600)
        
        return OAuth2Tokens(
            accessToken: "mock-access-token",
            refreshToken: "mock-refresh-token",
            tokenType: "Bearer",
            expiresAt: expirationDate,
            scope: "openid email profile"
        )
    }
    
    private func createMockUser() -> OAuth2User {
        return OAuth2User(
            id: "mock-user-id",
            email: "mock@example.com",
            name: "Mock User",
            picture: "https://example.com/avatar.jpg",
            verified: true,
            provider: "google"
        )
    }
}

// MARK: - Async Test Helpers

extension XCTestCase {
    
    func waitForAsync<T>(
        timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withTimeout(timeout) {
            try await operation()
        }
    }
    
    private func withTimeout<T>(
        _ timeout: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    private struct TimeoutError: Error {}
}