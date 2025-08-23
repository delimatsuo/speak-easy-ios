//
//  OAuth2ManagerTests.swift
//  UniversalTranslatorTests
//
//  Comprehensive test suite for OAuth2Manager covering authentication flows,
//  token management, error scenarios, and security edge cases.
//

import XCTest
import Foundation
import Combine
@testable import UniversalTranslator

// MARK: - Mock Network Session

class MockURLSession: URLSessionProtocol {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    var requestDelay: TimeInterval = 0
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if requestDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(requestDelay * 1_000_000_000))
        }
        
        if let error = error {
            throw error
        }
        
        let data = self.data ?? Data()
        let response = self.response ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (data, response)
    }
}

// MARK: - Mock Keychain Manager

class MockKeychainManager: KeychainManagerProtocol {
    private var storage: [String: Data] = [:]
    var shouldFail = false
    
    func save(_ data: Data, forKey key: String) throws {
        if shouldFail {
            throw KeychainError.unableToSave
        }
        storage[key] = data
    }
    
    func load(key: String) throws -> Data {
        if shouldFail {
            throw KeychainError.itemNotFound
        }
        guard let data = storage[key] else {
            throw KeychainError.itemNotFound
        }
        return data
    }
    
    func delete(key: String) throws {
        if shouldFail {
            throw KeychainError.unableToDelete
        }
        storage.removeValue(forKey: key)
    }
    
    func clear() {
        storage.removeAll()
    }
}

// MARK: - OAuth2Manager Tests

class OAuth2ManagerTests: XCTestCase {
    var oauth2Manager: OAuth2Manager!
    var mockSession: MockURLSession!
    var mockKeychain: MockKeychainManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        mockKeychain = MockKeychainManager()
        cancellables = Set<AnyCancellable>()
        
        // Create OAuth2Manager with mocked dependencies
        oauth2Manager = OAuth2Manager(
            config: OAuth2Configuration.google,
            session: mockSession,
            keychain: mockKeychain
        )
    }
    
    override func tearDown() {
        oauth2Manager = nil
        mockSession = nil
        mockKeychain = nil
        cancellables?.removeAll()
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Authentication Flow Tests
    
    func testAuthorizationURL() {
        // Given
        let config = OAuth2Configuration.google
        
        // When
        let authURL = oauth2Manager.authorizationURL()
        
        // Then
        XCTAssertNotNil(authURL)
        
        let urlComponents = URLComponents(url: authURL, resolvingAgainstBaseURL: false)
        XCTAssertEqual(urlComponents?.host, \"accounts.google.com\")
        XCTAssertEqual(urlComponents?.path, \"/o/oauth2/auth\")
        
        let queryItems = urlComponents?.queryItems ?? []
        let queryDict = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? \"\") })
        
        XCTAssertEqual(queryDict[\"client_id\"], config.clientId)
        XCTAssertEqual(queryDict[\"response_type\"], \"code\")
        XCTAssertEqual(queryDict[\"redirect_uri\"], config.redirectUri)
        XCTAssertNotNil(queryDict[\"state\"])
        XCTAssertNotNil(queryDict[\"code_challenge\"])
        XCTAssertEqual(queryDict[\"code_challenge_method\"], \"S256\")
    }
    
    func testSuccessfulTokenExchange() async {
        // Given
        let authorizationCode = \"test_auth_code\"
        let expectedToken = OAuth2Token(\n            accessToken: \"access_token_123\",\n            refreshToken: \"refresh_token_456\",\n            expiresAt: Date().addingTimeInterval(3600),\n            scope: [\"openid\", \"email\", \"profile\"]\n        )\n        \n        let tokenResponse = TokenResponse(\n            accessToken: expectedToken.accessToken,\n            refreshToken: expectedToken.refreshToken,\n            expiresIn: 3600,\n            scope: \"openid email profile\"\n        )\n        \n        mockSession.data = try! JSONEncoder().encode(tokenResponse)\n        mockSession.response = HTTPURLResponse(\n            url: URL(string: \"https://oauth2.googleapis.com/token\")!,\n            statusCode: 200,\n            httpVersion: nil,\n            headerFields: [\"Content-Type\": \"application/json\"]\n        )\n        \n        var receivedToken: OAuth2Token?\n        var receivedError: Error?\n        \n        // When\n        do {\n            receivedToken = try await oauth2Manager.exchangeCodeForToken(code: authorizationCode)\n        } catch {\n            receivedError = error\n        }\n        \n        // Then\n        XCTAssertNil(receivedError)\n        XCTAssertNotNil(receivedToken)\n        XCTAssertEqual(receivedToken?.accessToken, expectedToken.accessToken)\n        XCTAssertEqual(receivedToken?.refreshToken, expectedToken.refreshToken)\n        XCTAssertTrue(oauth2Manager.isAuthenticated)\n    }\n    \n    func testFailedTokenExchange() async {\n        // Given\n        let authorizationCode = \"invalid_code\"\n        let errorResponse = OAuth2ErrorResponse(\n            error: \"invalid_grant\",\n            errorDescription: \"The provided authorization grant is invalid\"\n        )\n        \n        mockSession.data = try! JSONEncoder().encode(errorResponse)\n        mockSession.response = HTTPURLResponse(\n            url: URL(string: \"https://oauth2.googleapis.com/token\")!,\n            statusCode: 400,\n            httpVersion: nil,\n            headerFields: [\"Content-Type\": \"application/json\"]\n        )\n        \n        var receivedToken: OAuth2Token?\n        var receivedError: OAuth2Error?\n        \n        // When\n        do {\n            receivedToken = try await oauth2Manager.exchangeCodeForToken(code: authorizationCode)\n        } catch let error as OAuth2Error {\n            receivedError = error\n        }\n        \n        // Then\n        XCTAssertNil(receivedToken)\n        XCTAssertNotNil(receivedError)\n        if case .serverError(let code, let description) = receivedError {\n            XCTAssertEqual(code, \"invalid_grant\")\n            XCTAssertEqual(description, \"The provided authorization grant is invalid\")\n        } else {\n            XCTFail(\"Expected serverError but got \\(String(describing: receivedError))\")\n        }\n        XCTAssertFalse(oauth2Manager.isAuthenticated)\n    }\n    \n    // MARK: - Token Management Tests\n    \n    func testTokenStorage() async {\n        // Given\n        let token = OAuth2Token(\n            accessToken: \"access_token_123\",\n            refreshToken: \"refresh_token_456\",\n            expiresAt: Date().addingTimeInterval(3600),\n            scope: [\"openid\", \"email\"]\n        )\n        \n        // When\n        try! await oauth2Manager.storeToken(token)\n        let retrievedToken = oauth2Manager.currentToken\n        \n        // Then\n        XCTAssertNotNil(retrievedToken)\n        XCTAssertEqual(retrievedToken?.accessToken, token.accessToken)\n        XCTAssertEqual(retrievedToken?.refreshToken, token.refreshToken)\n        XCTAssertTrue(oauth2Manager.isAuthenticated)\n    }\n    \n    func testTokenStorageFailure() async {\n        // Given\n        let token = OAuth2Token(\n            accessToken: \"access_token_123\",\n            refreshToken: \"refresh_token_456\",\n            expiresAt: Date().addingTimeInterval(3600),\n            scope: [\"openid\"]\n        )\n        mockKeychain.shouldFail = true\n        \n        var thrownError: Error?\n        \n        // When\n        do {\n            try await oauth2Manager.storeToken(token)\n        } catch {\n            thrownError = error\n        }\n        \n        // Then\n        XCTAssertNotNil(thrownError)\n        XCTAssertNil(oauth2Manager.currentToken)\n        XCTAssertFalse(oauth2Manager.isAuthenticated)\n    }\n    \n    func testTokenExpiration() {\n        // Given\n        let expiredToken = OAuth2Token(\n            accessToken: \"expired_token\",\n            refreshToken: \"refresh_token\",\n            expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago\n            scope: [\"openid\"]\n        )\n        \n        // When\n        oauth2Manager.currentToken = expiredToken\n        \n        // Then\n        XCTAssertTrue(oauth2Manager.isTokenExpired)\n        XCTAssertFalse(oauth2Manager.isAuthenticated) // Should be false for expired tokens\n    }\n    \n    // MARK: - Token Refresh Tests\n    \n    func testSuccessfulTokenRefresh() async {\n        // Given\n        let originalToken = OAuth2Token(\n            accessToken: \"old_access_token\",\n            refreshToken: \"valid_refresh_token\",\n            expiresAt: Date().addingTimeInterval(-300), // Expired 5 minutes ago\n            scope: [\"openid\", \"email\"]\n        )\n        oauth2Manager.currentToken = originalToken\n        \n        let refreshResponse = TokenResponse(\n            accessToken: \"new_access_token\",\n            refreshToken: \"new_refresh_token\",\n            expiresIn: 3600,\n            scope: \"openid email\"\n        )\n        \n        mockSession.data = try! JSONEncoder().encode(refreshResponse)\n        mockSession.response = HTTPURLResponse(\n            url: URL(string: \"https://oauth2.googleapis.com/token\")!,\n            statusCode: 200,\n            httpVersion: nil,\n            headerFields: [\"Content-Type\": \"application/json\"]\n        )\n        \n        var refreshedToken: OAuth2Token?\n        var refreshError: Error?\n        \n        // When\n        do {\n            refreshedToken = try await oauth2Manager.refreshToken()\n        } catch {\n            refreshError = error\n        }\n        \n        // Then\n        XCTAssertNil(refreshError)\n        XCTAssertNotNil(refreshedToken)\n        XCTAssertEqual(refreshedToken?.accessToken, \"new_access_token\")\n        XCTAssertEqual(refreshedToken?.refreshToken, \"new_refresh_token\")\n        XCTAssertFalse(oauth2Manager.isTokenExpired)\n        XCTAssertTrue(oauth2Manager.isAuthenticated)\n    }\n    \n    func testFailedTokenRefresh() async {\n        // Given\n        let originalToken = OAuth2Token(\n            accessToken: \"old_access_token\",\n            refreshToken: \"invalid_refresh_token\",\n            expiresAt: Date().addingTimeInterval(-300),\n            scope: [\"openid\"]\n        )\n        oauth2Manager.currentToken = originalToken\n        \n        let errorResponse = OAuth2ErrorResponse(\n            error: \"invalid_grant\",\n            errorDescription: \"Token has been expired or revoked\"\n        )\n        \n        mockSession.data = try! JSONEncoder().encode(errorResponse)\n        mockSession.response = HTTPURLResponse(\n            url: URL(string: \"https://oauth2.googleapis.com/token\")!,\n            statusCode: 400,\n            httpVersion: nil,\n            headerFields: [\"Content-Type\": \"application/json\"]\n        )\n        \n        var refreshedToken: OAuth2Token?\n        var refreshError: OAuth2Error?\n        \n        // When\n        do {\n            refreshedToken = try await oauth2Manager.refreshToken()\n        } catch let error as OAuth2Error {\n            refreshError = error\n        }\n        \n        // Then\n        XCTAssertNil(refreshedToken)\n        XCTAssertNotNil(refreshError)\n        XCTAssertNil(oauth2Manager.currentToken) // Should clear token on refresh failure\n        XCTAssertFalse(oauth2Manager.isAuthenticated)\n    }\n    \n    // MARK: - Security Tests\n    \n    func testPKCECodeGeneration() {\n        // Given & When\n        let codeVerifier1 = oauth2Manager.generateCodeVerifier()\n        let codeVerifier2 = oauth2Manager.generateCodeVerifier()\n        \n        // Then\n        XCTAssertNotEqual(codeVerifier1, codeVerifier2) // Should be unique\n        XCTAssertGreaterThanOrEqual(codeVerifier1.count, 43)\n        XCTAssertLessThanOrEqual(codeVerifier1.count, 128)\n        \n        // Should only contain URL-safe characters\n        let allowedCharacters = CharacterSet(charactersIn: \"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~\")\n        XCTAssertTrue(codeVerifier1.rangeOfCharacter(from: allowedCharacters.inverted) == nil)\n    }\n    \n    func testPKCEChallengeGeneration() {\n        // Given\n        let codeVerifier = \"dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk\"\n        \n        // When\n        let codeChallenge = oauth2Manager.generateCodeChallenge(from: codeVerifier)\n        \n        // Then\n        XCTAssertEqual(codeChallenge, \"E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM\")\n    }\n    \n    func testStateParameterGeneration() {\n        // Given & When\n        let state1 = oauth2Manager.generateState()\n        let state2 = oauth2Manager.generateState()\n        \n        // Then\n        XCTAssertNotEqual(state1, state2) // Should be unique\n        XCTAssertEqual(state1.count, 32) // Should be 32 characters\n        \n        // Should only contain alphanumeric characters\n        let allowedCharacters = CharacterSet.alphanumerics\n        XCTAssertTrue(state1.rangeOfCharacter(from: allowedCharacters.inverted) == nil)\n    }\n    \n    // MARK: - Edge Cases and Error Handling\n    \n    func testNetworkTimeoutHandling() async {\n        // Given\n        let authorizationCode = \"test_code\"\n        mockSession.requestDelay = 35.0 // Simulate timeout\n        mockSession.error = URLError(.timedOut)\n        \n        var receivedError: OAuth2Error?\n        \n        // When\n        do {\n            _ = try await oauth2Manager.exchangeCodeForToken(code: authorizationCode)\n        } catch let error as OAuth2Error {\n            receivedError = error\n        }\n        \n        // Then\n        XCTAssertNotNil(receivedError)\n        if case .networkError(let underlyingError) = receivedError {\n            XCTAssertTrue(underlyingError is URLError)\n        } else {\n            XCTFail(\"Expected networkError but got \\(String(describing: receivedError))\")\n        }\n    }\n    \n    func testInvalidJSONResponse() async {\n        // Given\n        let authorizationCode = \"test_code\"\n        mockSession.data = \"invalid json\".data(using: .utf8)\n        mockSession.response = HTTPURLResponse(\n            url: URL(string: \"https://oauth2.googleapis.com/token\")!,\n            statusCode: 200,\n            httpVersion: nil,\n            headerFields: [\"Content-Type\": \"application/json\"]\n        )\n        \n        var receivedError: OAuth2Error?\n        \n        // When\n        do {\n            _ = try await oauth2Manager.exchangeCodeForToken(code: authorizationCode)\n        } catch let error as OAuth2Error {\n            receivedError = error\n        }\n        \n        // Then\n        XCTAssertNotNil(receivedError)\n        if case .invalidResponse = receivedError {\n            // Expected\n        } else {\n            XCTFail(\"Expected invalidResponse but got \\(String(describing: receivedError))\")\n        }\n    }\n    \n    func testConcurrentTokenRefresh() async {\n        // Given\n        let expiredToken = OAuth2Token(\n            accessToken: \"expired_token\",\n            refreshToken: \"valid_refresh_token\",\n            expiresAt: Date().addingTimeInterval(-300),\n            scope: [\"openid\"]\n        )\n        oauth2Manager.currentToken = expiredToken\n        \n        let refreshResponse = TokenResponse(\n            accessToken: \"new_access_token\",\n            refreshToken: \"new_refresh_token\",\n            expiresIn: 3600,\n            scope: \"openid\"\n        )\n        \n        mockSession.data = try! JSONEncoder().encode(refreshResponse)\n        mockSession.response = HTTPURLResponse(\n            url: URL(string: \"https://oauth2.googleapis.com/token\")!,\n            statusCode: 200,\n            httpVersion: nil,\n            headerFields: [\"Content-Type\": \"application/json\"]\n        )\n        mockSession.requestDelay = 1.0 // Add delay to test concurrency\n        \n        // When - Make multiple concurrent refresh requests\n        async let result1 = oauth2Manager.refreshToken()\n        async let result2 = oauth2Manager.refreshToken()\n        async let result3 = oauth2Manager.refreshToken()\n        \n        let results = await [result1, result2, result3]\n        \n        // Then - All should succeed with the same token\n        for result in results {\n            do {\n                let token = try result.get()\n                XCTAssertEqual(token.accessToken, \"new_access_token\")\n            } catch {\n                XCTFail(\"Token refresh should not fail: \\(error)\")\n            }\n        }\n    }\n    \n    // MARK: - Authentication State Tests\n    \n    func testAuthenticationStatePublisher() {\n        // Given\n        let expectation = expectation(description: \"Authentication state changes\")\n        var receivedStates: [Bool] = []\n        \n        oauth2Manager.$isAuthenticated\n            .sink { isAuthenticated in\n                receivedStates.append(isAuthenticated)\n                if receivedStates.count >= 3 {\n                    expectation.fulfill()\n                }\n            }\n            .store(in: &cancellables)\n        \n        // When\n        let validToken = OAuth2Token(\n            accessToken: \"valid_token\",\n            refreshToken: \"refresh_token\",\n            expiresAt: Date().addingTimeInterval(3600),\n            scope: [\"openid\"]\n        )\n        oauth2Manager.currentToken = validToken // Should trigger true\n        oauth2Manager.signOut() // Should trigger false\n        \n        // Then\n        waitForExpectations(timeout: 2.0) { _ in\n            XCTAssertEqual(receivedStates, [false, true, false])\n        }\n    }\n    \n    func testSignOut() {\n        // Given\n        let token = OAuth2Token(\n            accessToken: \"access_token\",\n            refreshToken: \"refresh_token\",\n            expiresAt: Date().addingTimeInterval(3600),\n            scope: [\"openid\"]\n        )\n        oauth2Manager.currentToken = token\n        XCTAssertTrue(oauth2Manager.isAuthenticated)\n        \n        // When\n        oauth2Manager.signOut()\n        \n        // Then\n        XCTAssertNil(oauth2Manager.currentToken)\n        XCTAssertFalse(oauth2Manager.isAuthenticated)\n    }\n    \n    // MARK: - Configuration Tests\n    \n    func testGoogleConfiguration() {\n        // Given & When\n        let config = OAuth2Configuration.google\n        \n        // Then\n        XCTAssertEqual(config.authorizationEndpoint, \"https://accounts.google.com/o/oauth2/auth\")\n        XCTAssertEqual(config.tokenEndpoint, \"https://oauth2.googleapis.com/token\")\n        XCTAssertTrue(config.scopes.contains(\"openid\"))\n        XCTAssertTrue(config.scopes.contains(\"email\"))\n        XCTAssertTrue(config.scopes.contains(\"profile\"))\n    }\n    \n    func testMicrosoftConfiguration() {\n        // Given & When\n        let config = OAuth2Configuration.microsoft\n        \n        // Then\n        XCTAssertTrue(config.authorizationEndpoint.contains(\"login.microsoftonline.com\"))\n        XCTAssertTrue(config.tokenEndpoint.contains(\"login.microsoftonline.com\"))\n        XCTAssertTrue(config.scopes.contains(\"openid\"))\n        XCTAssertTrue(config.scopes.contains(\"email\"))\n    }\n}\n\n// MARK: - Test Extensions\n\nextension OAuth2ManagerTests {\n    func createValidToken(expiresIn seconds: TimeInterval = 3600) -> OAuth2Token {\n        return OAuth2Token(\n            accessToken: \"valid_access_token\",\n            refreshToken: \"valid_refresh_token\",\n            expiresAt: Date().addingTimeInterval(seconds),\n            scope: [\"openid\", \"email\", \"profile\"]\n        )\n    }\n    \n    func createExpiredToken() -> OAuth2Token {\n        return createValidToken(expiresIn: -3600) // Expired 1 hour ago\n    }\n}\n"