import Foundation

struct AppConfig {
    // MARK: - API Configuration
    
    /// Base URL for API endpoints - loaded from environment/build configuration
    static let apiBaseURL: String = {
        #if DEBUG
        // Local development
        if let override = ProcessInfo.processInfo.environment["LOCAL_API_URL"] {
            return override
        }
        return "http://localhost:8080"
        #else
        // Production - URL is injected via Info.plist during build
        if let productionURL = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !productionURL.isEmpty,
           productionURL != "$(API_BASE_URL)" { // Xcode placeholder check
            return productionURL
        }
        
        // Fallback to environment variable
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
            return envURL
        }
        
        // Final fallback (should not happen in production)
        assertionFailure("Production API URL not configured")
        return "https://universal-translator-api.a.run.app"
        #endif
    }()
    
    // MARK: - Endpoint Configuration
    
    struct Endpoints {
        static let translation = "/api/v1/translate"
        static let languageDetection = "/api/v1/detect-language"
        static let textToSpeech = "/api/v1/text-to-speech"
        static let health = "/health"
        static let metrics = "/metrics"
    }
    
    // MARK: - Firebase Configuration
    
    struct Firebase {
        /// Firebase configuration is loaded from GoogleService-Info.plist
        /// No hardcoded values needed - Firebase SDK handles this automatically
        
        static let isConfigured: Bool = {
            guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                  let plist = NSDictionary(contentsOfFile: path) else {
                print("⚠️ Firebase configuration file not found")
                return false
            }
            
            // Validate required Firebase configuration keys
            let requiredKeys = ["PROJECT_ID", "BUNDLE_ID", "API_KEY", "GCM_SENDER_ID"]
            for key in requiredKeys {
                guard plist[key] != nil else {
                    print("⚠️ Missing Firebase configuration key: \(key)")
                    return false
                }
            }
            
            return true
        }()
    }
    
    // MARK: - Performance Configuration
    
    struct Performance {
        static let apiTimeout: TimeInterval = 30.0
        static let retryAttempts: Int = 3
        static let rateLimit: Int = 60 // requests per minute
        static let cacheSize: Int = 50 * 1024 * 1024 // 50MB
        
        static let enablePerformanceMonitoring: Bool = {
            #if DEBUG
            return true
            #else
            return Bundle.main.object(forInfoDictionaryKey: "ENABLE_PERFORMANCE_MONITORING") as? Bool ?? true
            #endif
        }()
    }
    
    // MARK: - Security Configuration
    
    struct Security {
        /// Certificate pinning is handled by NetworkSecurityManager
        /// No hardcoded certificates here
        
        static let enableCertificatePinning: Bool = {
            #if DEBUG
            return false // Disabled for local development
            #else
            return true
            #endif
        }()
        
        static let apiKeyValidation: Bool = true
        static let requestSigning: Bool = true
        static let responseValidation: Bool = true
    }
    
    // MARK: - Feature Flags
    
    struct Features {
        static let offlineMode: Bool = true
        static let hapticFeedback: Bool = true
        static let liveActivities: Bool = {
            if #available(iOS 16.1, *) {
                return true
            }
            return false
        }()
        static let dynamicIsland: Bool = {
            if #available(iOS 16.1, *) {
                return true
            }
            return false
        }()
    }
    
    // MARK: - Debug Configuration
    
    struct Debug {
        static let enableLogging: Bool = {
            #if DEBUG
            return true
            #else
            return Bundle.main.object(forInfoDictionaryKey: "ENABLE_DEBUG_LOGGING") as? Bool ?? false
            #endif
        }()
        
        static let logLevel: LogLevel = {
            #if DEBUG
            return .debug
            #else
            return .error
            #endif
        }()
    }
    
    enum LogLevel: Int, CaseIterable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        var description: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            }
        }
    }
    
    // MARK: - Validation
    
    /// Validates the current configuration
    static func validateConfiguration() -> ConfigurationResult {
        var issues: [String] = []
        
        // Validate API URL
        guard !apiBaseURL.isEmpty else {
            issues.append("API Base URL is empty")
            return .invalid(issues)
        }
        
        guard URL(string: apiBaseURL) != nil else {
            issues.append("API Base URL is not a valid URL: \(apiBaseURL)")
            return .invalid(issues)
        }
        
        // Validate Firebase configuration in production
        #if !DEBUG
        guard Firebase.isConfigured else {
            issues.append("Firebase configuration is missing or invalid")
            return .invalid(issues)
        }
        #endif
        
        // Validate security settings
        #if !DEBUG
        guard Security.enableCertificatePinning else {
            issues.append("Certificate pinning should be enabled in production")
            return .invalid(issues)
        }
        #endif
        
        if issues.isEmpty {
            return .valid
        } else {
            return .invalid(issues)
        }
    }
    
    enum ConfigurationResult {
        case valid
        case invalid([String])
        
        var isValid: Bool {
            switch self {
            case .valid:
                return true
            case .invalid:
                return false
            }
        }
        
        var issues: [String] {
            switch self {
            case .valid:
                return []
            case .invalid(let problems):
                return problems
            }
        }
    }
    
    // MARK: - Environment Info
    
    /// Provides environment information for debugging
    static func environmentInfo() -> [String: Any] {
        return [
            "apiBaseURL": apiBaseURL,
            "isDebugBuild": Debug.enableLogging,
            "firebaseConfigured": Firebase.isConfigured,
            "certificatePinningEnabled": Security.enableCertificatePinning,
            "performanceMonitoringEnabled": Performance.enablePerformanceMonitoring,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "unknown",
            "appVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "unknown",
            "buildNumber": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") ?? "unknown"
        ]
    }
}

// MARK: - Configuration Logger

extension AppConfig {
    /// Logs the current configuration (safe for production - no secrets)
    static func logConfiguration() {
        guard Debug.enableLogging else { return }
        
        print("🔧 App Configuration:")
        print("   API Base URL: \(apiBaseURL)")
        print("   Firebase Configured: \(Firebase.isConfigured)")
        print("   Certificate Pinning: \(Security.enableCertificatePinning)")
        print("   Performance Monitoring: \(Performance.enablePerformanceMonitoring)")
        print("   Log Level: \(Debug.logLevel.description)")
        
        let validation = validateConfiguration()
        switch validation {
        case .valid:
            print("✅ Configuration is valid")
        case .invalid(let issues):
            print("❌ Configuration issues found:")
            for issue in issues {
                print("   • \(issue)")
            }
        }
    }
}