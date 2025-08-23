import Foundation
import SwiftUI
import Combine

/// Enhanced Authentication Manager that integrates OAuth 2.0 with existing app authentication
/// Provides backward compatibility while transitioning to OAuth-based authentication
@MainActor
public final class EnhancedAuthenticationManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: AuthenticatedUser?
    @Published public var authenticationState: AuthenticationState = .unauthenticated
    @Published public var isLoading: Bool = false
    @Published public var lastError: OAuth2Error?
    
    // MARK: - Private Properties
    private let oauth2Manager: OAuth2Manager
    private let legacyAPIKeyManager: APIKeyManager
    private let configuration: OAuth2Configuration
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Authentication State
    public enum AuthenticationState {
        case unauthenticated
        case authenticating
        case authenticated(OAuth2User)
        case anonymousMode
        case error(OAuth2Error)
        
        var isAuthenticated: Bool {
            switch self {
            case .authenticated:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Authenticated User Model
    public struct AuthenticatedUser {
        public let id: String
        public let email: String?
        public let name: String?
        public let picture: String?
        public let provider: String
        public let isOAuthUser: Bool
        public let creditsRemaining: Int
        
        public init(from oauth2User: OAuth2User, credits: Int = 0) {
            self.id = oauth2User.id
            self.email = oauth2User.email
            self.name = oauth2User.name
            self.picture = oauth2User.picture
            self.provider = oauth2User.provider
            self.isOAuthUser = true
            self.creditsRemaining = credits
        }
        
        public init(anonymousUserId: String, credits: Int) {
            self.id = anonymousUserId
            self.email = nil
            self.name = nil
            self.picture = nil
            self.provider = "anonymous"
            self.isOAuthUser = false
            self.creditsRemaining = credits
        }
    }
    
    // MARK: - Initialization
    public init() {
        self.configuration = OAuth2Configuration()
        self.oauth2Manager = OAuth2Manager(configuration: configuration)
        self.legacyAPIKeyManager = APIKeyManager()
        
        setupBindings()
        checkInitialAuthenticationState()
        
        // Log configuration status
        configuration.logConfigurationStatus()
    }
    
    // MARK: - Public Authentication Methods
    
    /// Authenticates user with OAuth 2.0 provider
    /// - Parameter provider: The OAuth provider to use
    public func authenticateWithOAuth(_ provider: OAuth2Provider) async throws {
        guard !isLoading else {
            throw OAuth2Error.concurrentAuthenticationAttempt
        }
        
        isLoading = true
        authenticationState = .authenticating
        defer { isLoading = false }
        
        do {
            try await oauth2Manager.authenticate(with: provider)
            
            // OAuth manager will update its published properties
            // Our bindings will handle the rest
            
        } catch {
            let oauth2Error = error as? OAuth2Error ?? OAuth2Error.authenticationFailed(error)
            lastError = oauth2Error
            authenticationState = .error(oauth2Error)
            SecurityLogger.shared.logOAuth2Error(oauth2Error)
            throw oauth2Error
        }
    }
    
    /// Continues with anonymous mode (legacy behavior)
    public func continueAnonymously() {
        let anonymousUserId = legacyAPIKeyManager.getDeviceId()
        let credits = AnonymousCreditsManager.shared.remainingCredits
        
        let anonymousUser = AuthenticatedUser(
            anonymousUserId: anonymousUserId,
            credits: credits
        )
        
        currentUser = anonymousUser
        isAuthenticated = true
        authenticationState = .anonymousMode
        
        SecurityLogger.shared.logInfo("User continued in anonymous mode", metadata: [
            "deviceId": anonymousUserId,
            "credits": credits
        ])
    }
    
    /// Refreshes the current authentication token
    public func refreshAuthentication() async throws {
        guard authenticationState.isAuthenticated else {
            throw OAuth2Error.noActiveSession
        }
        
        if let currentUser = currentUser, currentUser.isOAuthUser {
            try await oauth2Manager.refreshToken()
        }
        // Anonymous users don't need token refresh
    }
    
    /// Logs out the current user
    public func logout() async {
        defer {
            currentUser = nil
            isAuthenticated = false
            authenticationState = .unauthenticated
            lastError = nil
        }
        
        if let user = currentUser, user.isOAuthUser {
            await oauth2Manager.logout()
        }
        
        SecurityLogger.shared.logInfo("User logged out")
    }
    
    /// Gets a valid access token for API calls
    public func getValidAccessToken() async throws -> String {
        guard let user = currentUser else {
            throw OAuth2Error.noActiveSession
        }
        
        if user.isOAuthUser {
            return try await oauth2Manager.getValidAccessToken()
        } else {
            // Return API key for anonymous users
            return legacyAPIKeyManager.getAPIKey() ?? ""
        }
    }
    
    /// Checks if user has sufficient credits for operation
    public func hasCredits() -> Bool {
        guard let user = currentUser else { return false }
        
        if user.isOAuthUser {
            // OAuth users might have different credit systems
            return true // Implement OAuth user credit checking
        } else {
            return AnonymousCreditsManager.shared.remainingCredits > 0
        }
    }
    
    /// Updates credit count for current user
    public func updateCredits(_ newCount: Int) {
        guard var user = currentUser else { return }
        
        if !user.isOAuthUser {
            AnonymousCreditsManager.shared.updateCredits(newCount)
        }
        
        // Update user model
        currentUser = AuthenticatedUser(
            id: user.id,
            email: user.email,
            name: user.name,
            picture: user.picture,
            provider: user.provider,
            isOAuthUser: user.isOAuthUser,
            creditsRemaining: newCount
        )
    }
    
    // MARK: - Migration Helpers
    
    /// Determines if user should be prompted to migrate from anonymous to OAuth
    public var shouldPromptForOAuthMigration: Bool {
        guard let user = currentUser else { return false }
        return !user.isOAuthUser && user.creditsRemaining > 50 // Suggest migration for active users
    }
    
    /// Migrates anonymous user to OAuth authentication
    public func migrateToOAuth(_ provider: OAuth2Provider) async throws {
        // Store current anonymous data
        let previousCredits = currentUser?.creditsRemaining ?? 0
        
        // Authenticate with OAuth
        try await authenticateWithOAuth(provider)
        
        // Migrate credits if needed
        if previousCredits > 0 {
            // Implement credit migration logic
            updateCredits(previousCredits)
        }
        
        SecurityLogger.shared.logInfo("User migrated from anonymous to OAuth", metadata: [
            "provider": provider.rawValue,
            "migratedCredits": previousCredits
        ])
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind OAuth manager state to enhanced manager
        oauth2Manager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                self?.updateAuthenticationState(isAuth)
            }
            .store(in: &cancellables)
        
        oauth2Manager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] oauth2User in
                self?.updateCurrentUser(oauth2User)
            }
            .store(in: &cancellables)
    }
    
    private func updateAuthenticationState(_ isAuthenticated: Bool) {
        self.isAuthenticated = isAuthenticated
        
        if isAuthenticated, let oauth2User = oauth2Manager.currentUser {
            self.authenticationState = .authenticated(oauth2User)
        } else if !isAuthenticated && self.authenticationState != .anonymousMode {
            self.authenticationState = .unauthenticated
        }
    }
    
    private func updateCurrentUser(_ oauth2User: OAuth2User?) {
        if let oauth2User = oauth2User {
            // Get credits for OAuth user (implement OAuth credit system)
            let credits = getCreditsForOAuthUser(oauth2User)
            self.currentUser = AuthenticatedUser(from: oauth2User, credits: credits)
        } else if authenticationState != .anonymousMode {
            self.currentUser = nil
        }
    }
    
    private func getCreditsForOAuthUser(_ user: OAuth2User) -> Int {
        // Implement OAuth user credit retrieval
        // This could involve API calls to your backend
        return 1000 // Placeholder
    }
    
    private func checkInitialAuthenticationState() {
        // Check if there's a stored OAuth session
        Task {
            // OAuth2Manager will check stored tokens on init
            if !oauth2Manager.isAuthenticated {
                // Check if user was using anonymous mode
                if AnonymousCreditsManager.shared.remainingCredits > 0 {
                    continueAnonymously()
                }
            }
        }
    }
}

// MARK: - Authentication State Helpers
extension EnhancedAuthenticationManager {
    
    /// Determines the appropriate authentication flow based on app state
    public func getRecommendedAuthenticationFlow() -> AuthenticationFlow {
        let hasUsedApp = AnonymousCreditsManager.shared.totalCreditsUsed > 0
        let hasCredits = AnonymousCreditsManager.shared.remainingCredits > 0
        
        if hasUsedApp && hasCredits {
            return .promptForOAuthWithAnonymousOption
        } else if hasUsedApp {
            return .requireOAuth
        } else {
            return .offerBothOptions
        }
    }
    
    public enum AuthenticationFlow {
        case requireOAuth
        case offerBothOptions
        case promptForOAuthWithAnonymousOption
    }
}

// MARK: - Error Recovery
extension EnhancedAuthenticationManager {
    
    /// Attempts to recover from authentication errors
    public func recoverFromError() async {
        guard let error = lastError else { return }
        
        switch error {
        case .tokenExpired, .sessionExpired:
            do {
                try await refreshAuthentication()
                lastError = nil
            } catch {
                await logout()
            }
            
        case .noInternetConnection:
            // Retry when network is available
            lastError = nil
            
        case .biometricAuthenticationFailed:
            // User can retry biometric authentication
            lastError = nil
            
        default:
            // For other errors, logout and require reauthentication
            await logout()
        }
    }
    
    /// Checks if an error can be automatically recovered
    public func canAutoRecover(from error: OAuth2Error) -> Bool {
        return error.isRecoverable && !error.isSecurityError
    }
}

// MARK: - Convenience Extensions
extension EnhancedAuthenticationManager.AuthenticationState: Equatable {
    public static func == (lhs: EnhancedAuthenticationManager.AuthenticationState, rhs: EnhancedAuthenticationManager.AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated),
             (.authenticating, .authenticating),
             (.anonymousMode, .anonymousMode):
            return true
        case (.authenticated(let lUser), .authenticated(let rUser)):
            return lUser.id == rUser.id
        case (.error(let lError), .error(let rError)):
            return lError.category == rError.category
        default:
            return false
        }
    }
}

extension EnhancedAuthenticationManager.AuthenticatedUser: Equatable {
    public static func == (lhs: EnhancedAuthenticationManager.AuthenticatedUser, rhs: EnhancedAuthenticationManager.AuthenticatedUser) -> Bool {
        return lhs.id == rhs.id && lhs.provider == rhs.provider
    }
}

// MARK: - Legacy Compatibility
extension EnhancedAuthenticationManager {
    
    /// Legacy method for backward compatibility
    @available(*, deprecated, message: "Use authenticateWithOAuth(_:) instead")
    public func authenticateWithAPIKey() {
        continueAnonymously()
    }
    
    /// Legacy property for backward compatibility
    @available(*, deprecated, message: "Use authenticationState instead")
    public var isSignedIn: Bool {
        return isAuthenticated
    }
}