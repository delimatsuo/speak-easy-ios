import Foundation
import LocalAuthentication

/// Comprehensive error types for OAuth 2.0 authentication flow
/// Provides detailed error information for debugging and user experience
public enum OAuth2Error: Error, LocalizedError {
    
    // MARK: - Authentication Flow Errors
    case invalidAuthorizationURL
    case userCancelled
    case authenticationFailed(Error)
    case invalidCallback
    case serverError(String)
    case stateMismatch
    case noAuthorizationCode
    
    // MARK: - Token Exchange Errors
    case tokenExchangeFailed(Int)
    case tokenRefreshFailed(Int)
    case invalidResponse
    case noRefreshToken
    case tokenExpired
    case tokenNotFound
    case tokenDecryptionFailed
    
    // MARK: - User Information Errors
    case userInfoFetchFailed
    case invalidUserData
    
    // MARK: - Security Errors
    case biometricAuthenticationFailed(Error)
    case authenticationUnavailable
    case keychainAccessDenied
    case securityValidationFailed
    
    // MARK: - Session Management Errors
    case noActiveSession
    case sessionExpired
    case concurrentAuthenticationAttempt
    
    // MARK: - Network Errors
    case networkError(Int)
    case invalidURL
    case requestTimeout
    case noInternetConnection
    
    // MARK: - Configuration Errors
    case providerNotSupported
    case invalidConfiguration
    case missingClientCredentials
    
    // MARK: - LocalizedError Implementation
    public var errorDescription: String? {
        switch self {
        // Authentication Flow Errors
        case .invalidAuthorizationURL:
            return NSLocalizedString("Invalid authorization URL", comment: "OAuth error")
        case .userCancelled:
            return NSLocalizedString("Authentication was cancelled", comment: "OAuth error")
        case .authenticationFailed(let error):
            return NSLocalizedString("Authentication failed: \(error.localizedDescription)", comment: "OAuth error")
        case .invalidCallback:
            return NSLocalizedString("Invalid authentication callback", comment: "OAuth error")
        case .serverError(let message):
            return NSLocalizedString("Server error: \(message)", comment: "OAuth error")
        case .stateMismatch:
            return NSLocalizedString("Security validation failed", comment: "OAuth error")
        case .noAuthorizationCode:
            return NSLocalizedString("No authorization code received", comment: "OAuth error")
            
        // Token Exchange Errors
        case .tokenExchangeFailed(let statusCode):
            return NSLocalizedString("Token exchange failed (Status: \(statusCode))", comment: "OAuth error")
        case .tokenRefreshFailed(let statusCode):
            return NSLocalizedString("Token refresh failed (Status: \(statusCode))", comment: "OAuth error")
        case .invalidResponse:
            return NSLocalizedString("Invalid server response", comment: "OAuth error")
        case .noRefreshToken:
            return NSLocalizedString("No refresh token available", comment: "OAuth error")
        case .tokenExpired:
            return NSLocalizedString("Authentication token has expired", comment: "OAuth error")
        case .tokenNotFound:
            return NSLocalizedString("Authentication token not found", comment: "OAuth error")
        case .tokenDecryptionFailed:
            return NSLocalizedString("Failed to decrypt authentication token", comment: "OAuth error")
            
        // User Information Errors
        case .userInfoFetchFailed:
            return NSLocalizedString("Failed to fetch user information", comment: "OAuth error")
        case .invalidUserData:
            return NSLocalizedString("Invalid user data received", comment: "OAuth error")
            
        // Security Errors
        case .biometricAuthenticationFailed(let error):
            return NSLocalizedString("Biometric authentication failed: \(error.localizedDescription)", comment: "OAuth error")
        case .authenticationUnavailable:
            return NSLocalizedString("Device authentication is not available", comment: "OAuth error")
        case .keychainAccessDenied:
            return NSLocalizedString("Keychain access denied", comment: "OAuth error")
        case .securityValidationFailed:
            return NSLocalizedString("Security validation failed", comment: "OAuth error")
            
        // Session Management Errors
        case .noActiveSession:
            return NSLocalizedString("No active authentication session", comment: "OAuth error")
        case .sessionExpired:
            return NSLocalizedString("Authentication session has expired", comment: "OAuth error")
        case .concurrentAuthenticationAttempt:
            return NSLocalizedString("Another authentication is already in progress", comment: "OAuth error")
            
        // Network Errors
        case .networkError(let statusCode):
            return NSLocalizedString("Network error (Status: \(statusCode))", comment: "OAuth error")
        case .invalidURL:
            return NSLocalizedString("Invalid URL", comment: "OAuth error")
        case .requestTimeout:
            return NSLocalizedString("Request timed out", comment: "OAuth error")
        case .noInternetConnection:
            return NSLocalizedString("No internet connection", comment: "OAuth error")
            
        // Configuration Errors
        case .providerNotSupported:
            return NSLocalizedString("OAuth provider not supported", comment: "OAuth error")
        case .invalidConfiguration:
            return NSLocalizedString("Invalid OAuth configuration", comment: "OAuth error")
        case .missingClientCredentials:
            return NSLocalizedString("Missing client credentials", comment: "OAuth error")
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .userCancelled:
            return NSLocalizedString("The user cancelled the authentication process", comment: "OAuth failure reason")
        case .tokenExpired:
            return NSLocalizedString("The authentication token needs to be refreshed", comment: "OAuth failure reason")
        case .noInternetConnection:
            return NSLocalizedString("Please check your internet connection and try again", comment: "OAuth failure reason")
        case .biometricAuthenticationFailed:
            return NSLocalizedString("Biometric authentication is required to access secure tokens", comment: "OAuth failure reason")
        case .sessionExpired:
            return NSLocalizedString("Please sign in again", comment: "OAuth failure reason")
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .userCancelled:
            return NSLocalizedString("Try signing in again", comment: "OAuth recovery suggestion")
        case .tokenExpired, .sessionExpired:
            return NSLocalizedString("Please sign in again to continue", comment: "OAuth recovery suggestion")
        case .noInternetConnection:
            return NSLocalizedString("Check your network connection and try again", comment: "OAuth recovery suggestion")
        case .biometricAuthenticationFailed:
            return NSLocalizedString("Use Face ID, Touch ID, or your device passcode to continue", comment: "OAuth recovery suggestion")
        case .authenticationUnavailable:
            return NSLocalizedString("Set up Face ID, Touch ID, or a passcode in Settings", comment: "OAuth recovery suggestion")
        case .invalidConfiguration, .missingClientCredentials:
            return NSLocalizedString("Please contact support", comment: "OAuth recovery suggestion")
        default:
            return NSLocalizedString("Try again or contact support if the problem continues", comment: "OAuth recovery suggestion")
        }
    }
}

// MARK: - Error Categories
extension OAuth2Error {
    
    /// Determines if the error is recoverable by the user
    public var isRecoverable: Bool {
        switch self {
        case .userCancelled, .tokenExpired, .sessionExpired, 
             .noInternetConnection, .requestTimeout,
             .biometricAuthenticationFailed, .networkError:
            return true
        case .invalidConfiguration, .missingClientCredentials,
             .providerNotSupported, .securityValidationFailed:
            return false
        default:
            return true
        }
    }
    
    /// Determines if the error requires user reauthentication
    public var requiresReauthentication: Bool {
        switch self {
        case .tokenExpired, .sessionExpired, .noActiveSession,
             .tokenRefreshFailed, .noRefreshToken:
            return true
        default:
            return false
        }
    }
    
    /// Determines if the error is a security-related issue
    public var isSecurityError: Bool {
        switch self {
        case .biometricAuthenticationFailed, .authenticationUnavailable,
             .keychainAccessDenied, .securityValidationFailed,
             .stateMismatch, .tokenDecryptionFailed:
            return true
        default:
            return false
        }
    }
    
    /// Determines if the error is network-related
    public var isNetworkError: Bool {
        switch self {
        case .networkError, .noInternetConnection, .requestTimeout,
             .invalidURL, .tokenExchangeFailed, .tokenRefreshFailed:
            return true
        default:
            return false
        }
    }
    
    /// Error category for analytics and logging
    public var category: String {
        switch self {
        case .invalidAuthorizationURL, .userCancelled, .authenticationFailed,
             .invalidCallback, .serverError, .stateMismatch, .noAuthorizationCode:
            return "authentication_flow"
        case .tokenExchangeFailed, .tokenRefreshFailed, .invalidResponse,
             .noRefreshToken, .tokenExpired, .tokenNotFound, .tokenDecryptionFailed:
            return "token_management"
        case .userInfoFetchFailed, .invalidUserData:
            return "user_information"
        case .biometricAuthenticationFailed, .authenticationUnavailable,
             .keychainAccessDenied, .securityValidationFailed:
            return "security"
        case .noActiveSession, .sessionExpired, .concurrentAuthenticationAttempt:
            return "session_management"
        case .networkError, .invalidURL, .requestTimeout, .noInternetConnection:
            return "network"
        case .providerNotSupported, .invalidConfiguration, .missingClientCredentials:
            return "configuration"
        }
    }
}

// MARK: - Error Reporting
extension OAuth2Error {
    
    /// Creates a user-friendly error message suitable for UI display
    public var userFriendlyMessage: String {
        switch self {
        case .userCancelled:
            return NSLocalizedString("Sign-in was cancelled", comment: "User-friendly OAuth error")
        case .noInternetConnection:
            return NSLocalizedString("No internet connection", comment: "User-friendly OAuth error")
        case .tokenExpired, .sessionExpired:
            return NSLocalizedString("Session expired - please sign in again", comment: "User-friendly OAuth error")
        case .biometricAuthenticationFailed:
            return NSLocalizedString("Authentication required", comment: "User-friendly OAuth error")
        case .authenticationUnavailable:
            return NSLocalizedString("Device authentication not set up", comment: "User-friendly OAuth error")
        case .requestTimeout:
            return NSLocalizedString("Connection timed out", comment: "User-friendly OAuth error")
        default:
            return NSLocalizedString("Authentication failed - please try again", comment: "User-friendly OAuth error")
        }
    }
    
    /// Additional context information for error reporting
    public var contextInfo: [String: Any] {
        var context: [String: Any] = [
            "category": category,
            "is_recoverable": isRecoverable,
            "requires_reauth": requiresReauthentication,
            "is_security_error": isSecurityError,
            "is_network_error": isNetworkError
        ]
        
        switch self {
        case .authenticationFailed(let error):
            context["underlying_error"] = error.localizedDescription
        case .serverError(let message):
            context["server_message"] = message
        case .tokenExchangeFailed(let statusCode), 
             .tokenRefreshFailed(let statusCode),
             .networkError(let statusCode):
            context["status_code"] = statusCode
        case .biometricAuthenticationFailed(let error):
            context["biometric_error"] = error.localizedDescription
            if let laError = error as? LAError {
                context["la_error_code"] = laError.code.rawValue
            }
        default:
            break
        }
        
        return context
    }
}

// MARK: - Error Factory
extension OAuth2Error {
    
    /// Creates an OAuth error from a network response
    public static func fromNetworkResponse(_ response: HTTPURLResponse?, data: Data?) -> OAuth2Error {
        guard let response = response else {
            return .invalidResponse
        }
        
        // Try to parse error from response body
        if let data = data,
           let errorResponse = try? JSONDecoder().decode(OAuth2ErrorResponse.self, from: data) {
            return .serverError(errorResponse.errorDescription ?? errorResponse.error)
        }
        
        // Fall back to status code
        switch response.statusCode {
        case 400:
            return .serverError("Bad Request")
        case 401:
            return .tokenExpired
        case 403:
            return .keychainAccessDenied
        case 404:
            return .invalidURL
        case 408:
            return .requestTimeout
        case 500...599:
            return .serverError("Server Error")
        default:
            return .networkError(response.statusCode)
        }
    }
    
    /// Creates an OAuth error from a URL session error
    public static func fromURLError(_ error: URLError) -> OAuth2Error {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection
        case .timedOut:
            return .requestTimeout
        case .badURL:
            return .invalidURL
        default:
            return .networkError(error.errorCode)
        }
    }
    
    /// Creates an OAuth error from a Local Authentication error
    public static func fromLAError(_ error: LAError) -> OAuth2Error {
        switch error.code {
        case .userCancel:
            return .userCancelled
        case .biometryNotAvailable, .biometryNotEnrolled:
            return .authenticationUnavailable
        case .authenticationFailed:
            return .biometricAuthenticationFailed(error)
        default:
            return .biometricAuthenticationFailed(error)
        }
    }
}

// MARK: - Supporting Types
private struct OAuth2ErrorResponse: Codable {
    let error: String
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - Logging Integration
extension SecurityLogger {
    
    /// Logs OAuth errors with appropriate severity
    func logOAuth2Error(_ error: OAuth2Error, context: [String: Any] = [:]) {
        var logContext = error.contextInfo
        logContext.merge(context) { _, new in new }
        
        if error.isSecurityError {
            logSecurityError("OAuth security error: \(error.localizedDescription)", context: logContext)
        } else if error.isNetworkError {
            logWarning("OAuth network error: \(error.localizedDescription)", metadata: logContext)
        } else if error.requiresReauthentication {
            logInfo("OAuth reauthentication required: \(error.localizedDescription)", metadata: logContext)
        } else {
            logError("OAuth error: \(error.localizedDescription)", error: error)
        }
    }
    
    func logAuthenticationSuccess(provider: String, userId: String) {
        logInfo("OAuth authentication successful", metadata: [
            "provider": provider,
            "userId": userId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func logAuthenticationFailure(provider: String, error: Error) {
        if let oauth2Error = error as? OAuth2Error {
            logOAuth2Error(oauth2Error, context: ["provider": provider])
        } else {
            logError("OAuth authentication failed for \(provider)", error: error)
        }
    }
    
    func logTokenRefresh(userId: String, provider: String) {
        logInfo("OAuth token refreshed", metadata: [
            "userId": userId,
            "provider": provider,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    func logTokenRefreshFailure(userId: String, error: Error) {
        if let oauth2Error = error as? OAuth2Error {
            logOAuth2Error(oauth2Error, context: ["userId": userId, "operation": "token_refresh"])
        } else {
            logError("OAuth token refresh failed for user \(userId)", error: error)
        }
    }
    
    func logLogout() {
        logInfo("OAuth logout successful", metadata: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
}