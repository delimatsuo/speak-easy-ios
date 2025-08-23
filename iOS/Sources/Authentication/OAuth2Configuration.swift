import Foundation

/// OAuth 2.0 configuration for different providers
/// Provides centralized configuration management for OAuth flows
public struct OAuth2Configuration {
    
    // MARK: - Provider Configurations
    private let providers: [OAuth2Provider: ProviderConfig]
    
    // MARK: - Initialization
    public init() {
        self.providers = [
            .google: Self.googleConfig(),
            .apple: Self.appleConfig(),
            .microsoft: Self.microsoftConfig(),
            .github: Self.githubConfig()
        ]
    }
    
    // MARK: - Public Methods
    
    /// Gets configuration for a specific provider
    /// - Parameter provider: The OAuth provider
    /// - Returns: Provider configuration
    public func providerConfig(for provider: OAuth2Provider) -> ProviderConfig {
        return providers[provider] ?? ProviderConfig.default
    }
    
    /// Gets all configured providers
    public var availableProviders: [OAuth2Provider] {
        return Array(providers.keys)
    }
    
    /// Validates if a redirect URI matches any configured provider
    /// - Parameter url: The redirect URL to validate
    /// - Returns: The matching provider, if any
    public func matchingProvider(for url: URL) -> OAuth2Provider? {
        return providers.first { provider, config in
            url.absoluteString.hasPrefix(config.redirectURI)
        }?.key
    }
    
    // MARK: - Provider Specific Configurations
    
    private static func googleConfig() -> ProviderConfig {
        return ProviderConfig(
            clientId: Bundle.main.infoDictionary?["GOOGLE_CLIENT_ID"] as? String ?? "",
            clientSecret: "", // Not needed for mobile PKCE flow
            authorizationEndpoint: "https://accounts.google.com/o/oauth2/v2/auth",
            tokenEndpoint: "https://oauth2.googleapis.com/token",
            revokeEndpoint: "https://oauth2.googleapis.com/revoke",
            userInfoEndpoint: "https://www.googleapis.com/oauth2/v2/userinfo",
            redirectURI: "com.universaltranslator://oauth/google",
            callbackURLScheme: "com.universaltranslator",
            scopes: [
                "openid",
                "email",
                "profile"
            ],
            additionalParameters: [:]
        )
    }
    
    private static func appleConfig() -> ProviderConfig {
        return ProviderConfig(
            clientId: Bundle.main.infoDictionary?["APPLE_CLIENT_ID"] as? String ?? "",
            clientSecret: "", // Not needed for Apple Sign In
            authorizationEndpoint: "https://appleid.apple.com/auth/authorize",
            tokenEndpoint: "https://appleid.apple.com/auth/token",
            revokeEndpoint: "https://appleid.apple.com/auth/revoke",
            userInfoEndpoint: "", // Apple provides user info in the token response
            redirectURI: "com.universaltranslator://oauth/apple",
            callbackURLScheme: "com.universaltranslator",
            scopes: [
                "name",
                "email"
            ],
            additionalParameters: [
                "response_mode": "form_post"
            ]
        )
    }
    
    private static func microsoftConfig() -> ProviderConfig {
        return ProviderConfig(
            clientId: Bundle.main.infoDictionary?["MICROSOFT_CLIENT_ID"] as? String ?? "",
            clientSecret: "",
            authorizationEndpoint: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
            tokenEndpoint: "https://login.microsoftonline.com/common/oauth2/v2.0/token",
            revokeEndpoint: "",
            userInfoEndpoint: "https://graph.microsoft.com/v1.0/me",
            redirectURI: "com.universaltranslator://oauth/microsoft",
            callbackURLScheme: "com.universaltranslator",
            scopes: [
                "openid",
                "email",
                "profile",
                "User.Read"
            ],
            additionalParameters: [:]
        )
    }
    
    private static func githubConfig() -> ProviderConfig {
        return ProviderConfig(
            clientId: Bundle.main.infoDictionary?["GITHUB_CLIENT_ID"] as? String ?? "",
            clientSecret: "",
            authorizationEndpoint: "https://github.com/login/oauth/authorize",
            tokenEndpoint: "https://github.com/login/oauth/access_token",
            revokeEndpoint: "",
            userInfoEndpoint: "https://api.github.com/user",
            redirectURI: "com.universaltranslator://oauth/github",
            callbackURLScheme: "com.universaltranslator",
            scopes: [
                "user:email",
                "read:user"
            ],
            additionalParameters: [:]
        )
    }
}

// MARK: - OAuth2Provider
public enum OAuth2Provider: String, CaseIterable, Identifiable {
    case google = "google"
    case apple = "apple"
    case microsoft = "microsoft"
    case github = "github"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .google:
            return "Google"
        case .apple:
            return "Apple"
        case .microsoft:
            return "Microsoft"
        case .github:
            return "GitHub"
        }
    }
    
    public var iconName: String {
        switch self {
        case .google:
            return "google.logo"
        case .apple:
            return "apple.logo"
        case .microsoft:
            return "microsoft.logo"
        case .github:
            return "github.logo"
        }
    }
    
    public var brandColor: String {
        switch self {
        case .google:
            return "#4285F4"
        case .apple:
            return "#000000"
        case .microsoft:
            return "#00A4EF"
        case .github:
            return "#24292E"
        }
    }
    
    /// Determines if the provider supports refresh tokens
    public var supportsRefreshTokens: Bool {
        switch self {
        case .google, .microsoft, .github:
            return true
        case .apple:
            return false // Apple Sign In uses different refresh mechanism
        }
    }
    
    /// Determines if the provider supports token revocation
    public var supportsTokenRevocation: Bool {
        switch self {
        case .google, .apple:
            return true
        case .microsoft, .github:
            return false
        }
    }
}

// MARK: - ProviderConfig
public struct ProviderConfig {
    public let clientId: String
    public let clientSecret: String
    public let authorizationEndpoint: String
    public let tokenEndpoint: String
    public let revokeEndpoint: String
    public let userInfoEndpoint: String
    public let redirectURI: String
    public let callbackURLScheme: String
    public let scopes: [String]
    public let additionalParameters: [String: String]
    
    public init(
        clientId: String,
        clientSecret: String = "",
        authorizationEndpoint: String,
        tokenEndpoint: String,
        revokeEndpoint: String = "",
        userInfoEndpoint: String,
        redirectURI: String,
        callbackURLScheme: String,
        scopes: [String],
        additionalParameters: [String: String] = [:]
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.revokeEndpoint = revokeEndpoint
        self.userInfoEndpoint = userInfoEndpoint
        self.redirectURI = redirectURI
        self.callbackURLScheme = callbackURLScheme
        self.scopes = scopes
        self.additionalParameters = additionalParameters
    }
    
    /// Default/empty configuration
    static let `default` = ProviderConfig(
        clientId: "",
        authorizationEndpoint: "",
        tokenEndpoint: "",
        userInfoEndpoint: "",
        redirectURI: "",
        callbackURLScheme: "",
        scopes: []
    )
    
    /// Validates that all required configuration values are present
    public var isValid: Bool {
        return !clientId.isEmpty &&
               !authorizationEndpoint.isEmpty &&
               !tokenEndpoint.isEmpty &&
               !redirectURI.isEmpty &&
               !callbackURLScheme.isEmpty
    }
    
    /// Gets the authorization URL with PKCE parameters
    public func authorizationURL(
        codeChallenge: String,
        state: String,
        additionalParams: [String: String] = [:]
    ) -> URL? {
        var components = URLComponents(string: authorizationEndpoint)
        
        var queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        // Add additional provider-specific parameters
        for (key, value) in additionalParameters.merging(additionalParams) { $1 } {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        
        components?.queryItems = queryItems
        return components?.url
    }
}

// MARK: - OAuth2Tokens
public struct OAuth2Tokens {
    public let accessToken: String
    public let refreshToken: String?
    public let tokenType: String
    public let expiresAt: Date?
    public let scope: String?
    
    public init(
        accessToken: String,
        refreshToken: String? = nil,
        tokenType: String = "Bearer",
        expiresAt: Date? = nil,
        scope: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.scope = scope
    }
    
    /// Creates OAuth2Tokens from token response
    public init(from response: TokenResponse) {
        self.accessToken = response.accessToken
        self.refreshToken = response.refreshToken
        self.tokenType = response.tokenType
        self.scope = response.scope
        
        // Calculate expiration date
        if let expiresIn = response.expiresIn {
            self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            self.expiresAt = nil
        }
    }
    
    /// Checks if the token is expired
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else {
            return false // If no expiration, assume valid
        }
        
        // Add 5 minute buffer before actual expiration
        let bufferTime: TimeInterval = 5 * 60
        return Date().addingTimeInterval(bufferTime) >= expiresAt
    }
    
    /// Time remaining until token expires
    public var timeUntilExpiration: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        return expiresAt.timeIntervalSince(Date())
    }
    
    /// Authorization header value
    public var authorizationHeader: String {
        return "\(tokenType) \(accessToken)"
    }
}

// MARK: - OAuth2User
public struct OAuth2User: Codable, Identifiable {
    public let id: String
    public let email: String?
    public let name: String?
    public let picture: String?
    public let verified: Bool
    public let provider: String
    
    public init(
        id: String,
        email: String?,
        name: String?,
        picture: String?,
        verified: Bool = false,
        provider: String
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.picture = picture
        self.verified = verified
        self.provider = provider
    }
    
    /// Creates OAuth2User from user info response
    public init(from response: UserInfoResponse, provider: String) {
        self.id = response.id
        self.email = response.email
        self.name = response.name
        self.picture = response.picture
        self.verified = response.verified ?? false
        self.provider = provider
    }
    
    /// Display name for UI
    public var displayName: String {
        return name ?? email ?? "User"
    }
    
    /// Initials for avatar
    public var initials: String {
        let components = displayName.components(separatedBy: " ")
        let initials = components.compactMap { $0.first }.map(String.init)
        return initials.joined().uppercased()
    }
}

// MARK: - Configuration Validation
extension OAuth2Configuration {
    
    /// Validates all provider configurations
    public func validateConfigurations() -> [OAuth2Provider: [String]] {
        var errors: [OAuth2Provider: [String]] = [:]
        
        for (provider, config) in providers {
            var providerErrors: [String] = []
            
            if config.clientId.isEmpty {
                providerErrors.append("Missing client ID")
            }
            
            if config.authorizationEndpoint.isEmpty {
                providerErrors.append("Missing authorization endpoint")
            }
            
            if config.tokenEndpoint.isEmpty {
                providerErrors.append("Missing token endpoint")
            }
            
            if config.redirectURI.isEmpty {
                providerErrors.append("Missing redirect URI")
            }
            
            if config.scopes.isEmpty {
                providerErrors.append("Missing scopes")
            }
            
            if !providerErrors.isEmpty {
                errors[provider] = providerErrors
            }
        }
        
        return errors
    }
    
    /// Logs configuration status
    public func logConfigurationStatus() {
        let errors = validateConfigurations()
        
        if errors.isEmpty {
            SecurityLogger.shared.logInfo("All OAuth configurations are valid")
        } else {
            for (provider, providerErrors) in errors {
                SecurityLogger.shared.logError(
                    "Invalid configuration for \(provider.displayName)",
                    error: ConfigurationError.invalidProvider(provider, providerErrors)
                )
            }
        }
    }
}

// MARK: - Configuration Errors
public enum ConfigurationError: Error, LocalizedError {
    case invalidProvider(OAuth2Provider, [String])
    case missingConfiguration(OAuth2Provider)
    
    public var errorDescription: String? {
        switch self {
        case .invalidProvider(let provider, let errors):
            return "Invalid configuration for \(provider.displayName): \(errors.joined(separator: ", "))"
        case .missingConfiguration(let provider):
            return "Missing configuration for \(provider.displayName)"
        }
    }
}

// MARK: - URL Handling Extensions
extension URL {
    /// Extracts OAuth parameters from callback URL
    public var oauthParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }
        
        var parameters: [String: String] = [:]
        for item in queryItems {
            parameters[item.name] = item.value
        }
        return parameters
    }
    
    /// Checks if URL is a valid OAuth redirect
    public func isOAuthRedirect(for configuration: OAuth2Configuration) -> Bool {
        return configuration.matchingProvider(for: self) != nil
    }
}