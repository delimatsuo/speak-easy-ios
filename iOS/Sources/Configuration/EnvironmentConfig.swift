//
//  EnvironmentConfig.swift
//  Mervyn Talks
//
//  Environment-specific configuration management
//  Handles development, staging, and production configurations
//

import Foundation

/// Application environment types
enum Environment: String, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    
    /// Current environment based on build configuration
    static var current: Environment {
        #if DEVELOPMENT
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }
    
    /// Environment display name
    var displayName: String {
        switch self {
        case .development:
            return "Development"
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        }
    }
}

/// Environment-specific configuration
struct EnvironmentConfig {
    
    // MARK: - API Configuration
    
    /// Base URL for the backend API
    static var apiBaseURL: String {
        switch Environment.current {
        case .development:
            // Check for environment variable first (for Xcode scheme configuration)
            if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
                return envURL
            }
            // Default development URLs
            #if targetEnvironment(simulator)
            return "http://localhost:8080"  // Simulator can use localhost
            #else
            return "http://192.168.1.100:8080"  // Device needs actual IP
            #endif
            
        case .staging:
            return "https://mervyn-talks-staging-\(stagingHash).run.app"
            
        case .production:
            return "https://universal-translator-prod-\(productionHash).run.app"
        }
    }
    
    /// API version path
    static var apiVersion: String {
        return "/v1"
    }
    
    /// Complete API base URL with version
    static var fullAPIBaseURL: String {
        return "\(apiBaseURL)\(apiVersion)"
    }
    
    // MARK: - Feature Flags
    
    /// Enable debug logging
    static var enableDebugLogs: Bool {
        switch Environment.current {
        case .development:
            return true
        case .staging:
            return true
        case .production:
            return false
        }
    }
    
    /// Enable testing features
    static var enableTestingFeatures: Bool {
        Environment.current != .production
    }
    
    /// Enable experimental features
    static var enableExperimentalFeatures: Bool {
        switch Environment.current {
        case .development:
            return true
        case .staging:
            return ProcessInfo.processInfo.environment["ENABLE_EXPERIMENTAL"] == "1"
        case .production:
            return false
        }
    }
    
    /// Enable crash reporting
    static var enableCrashReporting: Bool {
        Environment.current == .production
    }
    
    /// Enable analytics
    static var enableAnalytics: Bool {
        Environment.current != .development
    }
    
    // MARK: - Security Configuration
    
    /// Enable certificate pinning
    static var enableCertificatePinning: Bool {
        Environment.current == .production
    }
    
    /// API timeout interval
    static var apiTimeoutInterval: TimeInterval {
        switch Environment.current {
        case .development:
            return 60.0  // Longer timeout for debugging
        case .staging:
            return 30.0
        case .production:
            return 20.0
        }
    }
    
    /// Rate limiting configuration
    static var rateLimitEnabled: Bool {
        Environment.current != .development
    }
    
    // MARK: - Development Configuration
    
    /// Show environment indicator in UI
    static var showEnvironmentIndicator: Bool {
        Environment.current != .production
    }
    
    /// Enable dev menu
    static var enableDevMenu: Bool {
        Environment.current == .development
    }
    
    /// Mock external services
    static var mockExternalServices: Bool {
        Environment.current == .development && 
        ProcessInfo.processInfo.environment["MOCK_SERVICES"] == "1"
    }
    
    /// Skip onboarding for testing
    static var skipOnboarding: Bool {
        Environment.current == .development &&
        ProcessInfo.processInfo.environment["SKIP_ONBOARDING"] == "1"
    }
    
    // MARK: - Logging Configuration
    
    /// Log level
    static var logLevel: LogLevel {
        switch Environment.current {
        case .development:
            return .verbose
        case .staging:
            return .info
        case .production:
            return .warning
        }
    }
    
    /// Enable network request logging
    static var logNetworkRequests: Bool {
        Environment.current != .production
    }
    
    /// Enable performance monitoring
    static var enablePerformanceMonitoring: Bool {
        Environment.current != .development
    }
    
    // MARK: - UI Configuration
    
    /// Environment banner color
    static var environmentBannerColor: UIColor? {
        switch Environment.current {
        case .development:
            return .systemGreen
        case .staging:
            return .systemOrange
        case .production:
            return nil  // No banner in production
        }
    }
    
    /// App title suffix for non-production
    static var appTitleSuffix: String {
        switch Environment.current {
        case .development:
            return " [DEV]"
        case .staging:
            return " [STAGING]"
        case .production:
            return ""
        }
    }
    
    // MARK: - Cache Configuration
    
    /// Cache expiration time for translations
    static var translationCacheExpiration: TimeInterval {
        switch Environment.current {
        case .development:
            return 300  // 5 minutes for testing
        case .staging:
            return 1800  // 30 minutes
        case .production:
            return 3600  // 1 hour
        }
    }
    
    /// Maximum cache size in bytes
    static var maxCacheSize: Int {
        switch Environment.current {
        case .development:
            return 10 * 1024 * 1024  // 10 MB
        case .staging:
            return 50 * 1024 * 1024  // 50 MB
        case .production:
            return 100 * 1024 * 1024  // 100 MB
        }
    }
    
    // MARK: - Testing Configuration
    
    /// Enable UI testing helpers
    static var enableUITestingHelpers: Bool {
        ProcessInfo.processInfo.environment["UI_TESTING"] == "1" ||
        Environment.current == .development
    }
    
    /// Accessibility identifiers prefix
    static var accessibilityPrefix: String {
        return "MervynTalks"
    }
    
    // MARK: - Private Configuration
    
    /// Staging deployment hash (updated by CI/CD)
    private static let stagingHash = "staging-hash"
    
    /// Production deployment hash (updated by CI/CD)
    private static let productionHash = "prod-hash"
}

/// Log levels for environment configuration
enum LogLevel: Int, CaseIterable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    
    var name: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

// MARK: - Development Helpers

#if DEBUG
extension EnvironmentConfig {
    /// Print current configuration (development only)
    static func printConfiguration() {
        print("""
        🔧 MERVYN TALKS CONFIGURATION
        =============================
        Environment: \(Environment.current.displayName)
        API Base URL: \(apiBaseURL)
        Debug Logs: \(enableDebugLogs)
        Testing Features: \(enableTestingFeatures)
        Certificate Pinning: \(enableCertificatePinning)
        Crash Reporting: \(enableCrashReporting)
        Analytics: \(enableAnalytics)
        Log Level: \(logLevel.name)
        =============================
        """)
    }
    
    /// Validate configuration (development only)
    static func validateConfiguration() {
        // Check API URL accessibility
        guard let url = URL(string: apiBaseURL) else {
            print("⚠️ Invalid API Base URL: \(apiBaseURL)")
            return
        }
        
        // Additional validation can be added here
        print("✅ Configuration validation passed")
    }
}
#endif
