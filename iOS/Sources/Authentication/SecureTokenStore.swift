import Foundation
import Security
import LocalAuthentication

/// Secure token storage using iOS Keychain with biometric authentication
/// Provides enterprise-grade security for OAuth tokens
public final class SecureTokenStore {
    
    // MARK: - Constants
    private let service = "com.universaltranslator.oauth"
    private let accessGroup = "$(TeamIdentifierPrefix)com.universaltranslator.shared"
    
    // MARK: - Keychain Keys
    private enum KeychainKey {
        static func accessToken(userId: String, provider: String) -> String {
            return "oauth_access_token_\(provider)_\(userId)"
        }
        
        static func refreshToken(userId: String, provider: String) -> String {
            return "oauth_refresh_token_\(provider)_\(userId)"
        }
        
        static func tokenExpiration(userId: String, provider: String) -> String {
            return "oauth_token_expiration_\(provider)_\(userId)"
        }
        
        static func tokenMetadata(userId: String, provider: String) -> String {
            return "oauth_token_metadata_\(provider)_\(userId)"
        }
    }
    
    // MARK: - Public Methods
    
    /// Stores OAuth tokens securely in keychain with biometric protection
    /// - Parameters:
    ///   - tokens: The OAuth tokens to store
    ///   - userId: The user identifier
    ///   - provider: The OAuth provider name
    public func storeTokens(_ tokens: OAuth2Tokens, for userId: String, provider: String) async throws {
        
        // Validate biometric authentication if available
        try await validateBiometricAuthentication()
        
        // Store access token
        try await storeSecurely(
            data: tokens.accessToken.data(using: .utf8)!,
            key: KeychainKey.accessToken(userId: userId, provider: provider),
            requireBiometrics: true
        )
        
        // Store refresh token if available
        if let refreshToken = tokens.refreshToken {
            try await storeSecurely(
                data: refreshToken.data(using: .utf8)!,
                key: KeychainKey.refreshToken(userId: userId, provider: provider),
                requireBiometrics: true
            )
        }
        
        // Store expiration date
        if let expiresAt = tokens.expiresAt {
            let expirationData = try JSONEncoder().encode(expiresAt)
            try await storeSecurely(
                data: expirationData,
                key: KeychainKey.tokenExpiration(userId: userId, provider: provider),
                requireBiometrics: false // Expiration doesn't need biometrics
            )
        }
        
        // Store token metadata
        let metadata = TokenMetadata(
            tokenType: tokens.tokenType,
            scope: tokens.scope,
            createdAt: Date()
        )
        let metadataData = try JSONEncoder().encode(metadata)
        try await storeSecurely(
            data: metadataData,
            key: KeychainKey.tokenMetadata(userId: userId, provider: provider),
            requireBiometrics: false
        )
        
        SecurityLogger.shared.logTokenStorage(userId: userId, provider: provider)
    }
    
    /// Retrieves OAuth tokens from keychain with biometric authentication
    /// - Parameters:
    ///   - userId: The user identifier
    ///   - provider: The OAuth provider name
    /// - Returns: The stored OAuth tokens
    public func retrieveTokens(for userId: String, provider: String) async throws -> OAuth2Tokens {
        
        // Validate biometric authentication
        try await validateBiometricAuthentication()
        
        // Retrieve access token
        let accessTokenData = try await retrieveSecurely(
            key: KeychainKey.accessToken(userId: userId, provider: provider),
            requireBiometrics: true
        )
        
        guard let accessToken = String(data: accessTokenData, encoding: .utf8) else {
            throw OAuth2Error.tokenDecryptionFailed
        }
        
        // Retrieve refresh token (optional)
        var refreshToken: String?
        do {
            let refreshTokenData = try await retrieveSecurely(
                key: KeychainKey.refreshToken(userId: userId, provider: provider),
                requireBiometrics: true
            )
            refreshToken = String(data: refreshTokenData, encoding: .utf8)
        } catch {
            // Refresh token might not exist for some flows
            refreshToken = nil
        }
        
        // Retrieve expiration date
        var expiresAt: Date?
        do {
            let expirationData = try await retrieveSecurely(
                key: KeychainKey.tokenExpiration(userId: userId, provider: provider),
                requireBiometrics: false
            )
            expiresAt = try JSONDecoder().decode(Date.self, from: expirationData)
        } catch {
            // Expiration might not be set
            expiresAt = nil
        }
        
        // Retrieve metadata
        var metadata: TokenMetadata?
        do {
            let metadataData = try await retrieveSecurely(
                key: KeychainKey.tokenMetadata(userId: userId, provider: provider),
                requireBiometrics: false
            )
            metadata = try JSONDecoder().decode(TokenMetadata.self, from: metadataData)
        } catch {
            // Metadata might not exist for older tokens
            metadata = nil
        }
        
        SecurityLogger.shared.logTokenRetrieval(userId: userId, provider: provider)
        
        return OAuth2Tokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: metadata?.tokenType ?? "Bearer",
            expiresAt: expiresAt,
            scope: metadata?.scope
        )
    }
    
    /// Clears all stored tokens for a user and provider
    /// - Parameters:
    ///   - userId: The user identifier
    ///   - provider: The OAuth provider name
    public func clearTokens(for userId: String, provider: String) async throws {
        
        let keysToDelete = [
            KeychainKey.accessToken(userId: userId, provider: provider),
            KeychainKey.refreshToken(userId: userId, provider: provider),
            KeychainKey.tokenExpiration(userId: userId, provider: provider),
            KeychainKey.tokenMetadata(userId: userId, provider: provider)
        ]
        
        for key in keysToDelete {
            do {
                try await deleteSecurely(key: key)
            } catch {
                // Continue deleting other keys even if one fails
                SecurityLogger.shared.logError("Failed to delete keychain item", error: error)
            }
        }
        
        SecurityLogger.shared.logTokenCleanup(userId: userId, provider: provider)
    }
    
    /// Clears all tokens for all users (used during app reset)
    public func clearAllTokens() async throws {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
        
        SecurityLogger.shared.logAllTokensCleanup()
    }
    
    /// Checks if biometric authentication is available and enrolled
    public func isBiometricAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Updates token expiration time (used after token refresh)
    public func updateTokenExpiration(for userId: String, provider: String, expiresAt: Date) async throws {
        let expirationData = try JSONEncoder().encode(expiresAt)
        try await storeSecurely(
            data: expirationData,
            key: KeychainKey.tokenExpiration(userId: userId, provider: provider),
            requireBiometrics: false
        )
    }
    
    // MARK: - Private Methods
    
    /// Validates biometric authentication if available
    private func validateBiometricAuthentication() async throws {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // If biometrics not available, fall back to device passcode
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                throw OAuth2Error.authenticationUnavailable
            }
            return
        }
        
        // Request biometric authentication
        do {
            let reason = "Authenticate to access your secure tokens"
            _ = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            throw OAuth2Error.biometricAuthenticationFailed(error)
        }
    }
    
    /// Stores data securely in keychain
    private func storeSecurely(data: Data, key: String, requireBiometrics: Bool) async throws {
        
        // Delete existing item first
        try? await deleteSecurely(key: key)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        // Set access control based on biometric requirement
        if requireBiometrics && isBiometricAuthenticationAvailable() {
            let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryAny],
                nil
            )
            query[kSecAttrAccessControl as String] = access
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.storeFailed(status)
        }
    }
    
    /// Retrieves data securely from keychain
    private func retrieveSecurely(key: String, requireBiometrics: Bool) async throws -> Data {
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        // Add biometric prompt if required
        if requireBiometrics && isBiometricAuthenticationAvailable() {
            query[kSecUseOperationPrompt as String] = "Authenticate to access your secure tokens"
        }
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw OAuth2Error.tokenNotFound
            } else if status == errSecUserCancel {
                throw OAuth2Error.userCancelled
            } else {
                throw KeychainError.retrieveFailed(status)
            }
        }
        
        guard let data = item as? Data else {
            throw OAuth2Error.tokenDecryptionFailed
        }
        
        return data
    }
    
    /// Deletes data securely from keychain
    private func deleteSecurely(key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Supporting Types

/// Token metadata for additional security information
private struct TokenMetadata: Codable {
    let tokenType: String
    let scope: String?
    let createdAt: Date
}

/// Keychain operation errors
public enum KeychainError: Error, LocalizedError {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case conversionFailed
    
    public var errorDescription: String? {
        switch self {
        case .storeFailed(let status):
            return "Failed to store item in keychain: \(status)"
        case .retrieveFailed(let status):
            return "Failed to retrieve item from keychain: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete item from keychain: \(status)"
        case .conversionFailed:
            return "Failed to convert keychain data"
        }
    }
}

// MARK: - SecurityLogger Extension
extension SecurityLogger {
    func logTokenStorage(userId: String, provider: String) {
        logInfo("OAuth tokens stored securely", metadata: [
            "userId": userId,
            "provider": provider,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func logTokenRetrieval(userId: String, provider: String) {
        logInfo("OAuth tokens retrieved", metadata: [
            "userId": userId,
            "provider": provider,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func logTokenCleanup(userId: String, provider: String) {
        logInfo("OAuth tokens cleared", metadata: [
            "userId": userId,
            "provider": provider,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func logAllTokensCleanup() {
        logInfo("All OAuth tokens cleared", metadata: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
}