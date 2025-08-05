import Foundation

/// Application configuration for secure deployment
struct AppConfig {
    
    // MARK: - API Configuration
    
    /// Base URL for the translation API
    static let apiBaseURL: String = {
        #if DEBUG
        // Local development
        return ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8080"
        #else
        // Production - this will be set via build configuration
        return ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "https://universal-translator-api-xxxxx.a.run.app"
        #endif
    }()
    
    // MARK: - API Endpoints
    
    struct Endpoints {
        static let translation = "/v1/translate"
        static let languages = "/v1/languages"
        static let health = "/health"
        static let textToSpeech = "/v1/tts"  // Future TTS endpoint
    }
    
    // MARK: - Request Configuration
    
    struct Network {
        static let timeout: TimeInterval = 30.0
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 1.0
    }
    
    // MARK: - Security Configuration
    
    struct Security {
        /// Whether to use certificate pinning (enabled in production)
        static let useCertificatePinning: Bool = {
            #if DEBUG
            return false
            #else
            return true
            #endif
        }()
        
        /// Request timeout for security-sensitive operations
        static let secureTimeout: TimeInterval = 10.0
    }
    
    // MARK: - Cache Configuration
    
    struct Cache {
        static let maxAge: TimeInterval = 3600 // 1 hour
        static let maxEntries = 1000
        static let diskCacheEnabled = true
    }
    
    // MARK: - Feature Flags
    
    struct Features {
        static let offlineMode = true
        static let speechRecognition = true
        static let textToSpeech = true
        static let hapticFeedback = true
        static let darkModeSupport = true
    }
    
    // MARK: - Environment Detection
    
    static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
    
    static var environment: String {
        return isProduction ? "production" : "development"
    }
    
    // MARK: - Logging Configuration
    
    struct Logging {
        static let enabled: Bool = {
            #if DEBUG
            return true
            #else
            return ProcessInfo.processInfo.environment["ENABLE_LOGGING"] == "true"
            #endif
        }()
        
        static let level: LogLevel = {
            #if DEBUG
            return .debug
            #else
            return .info
            #endif
        }()
    }
    
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    // MARK: - Version Information
    
    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    static var userAgent: String {
        return "UniversalTranslator/\(appVersion) (\(buildNumber)) iOS/\(UIDevice.current.systemVersion)"
    }
}