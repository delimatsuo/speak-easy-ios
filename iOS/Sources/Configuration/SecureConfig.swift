//
//  SecureConfig.swift
//  Universal AI Translator
//
//  Secure configuration management for production deployment
//

import Foundation

/// Secure configuration management for API keys and sensitive data
class SecureConfig {
    static let shared = SecureConfig()
    
    private init() {}
    
    /// Retrieve API key from secure sources in priority order:
    /// 1. Environment variables (production)
    /// 2. GCP Secret Manager (cloud deployment)
    /// 3. Keychain (iOS secure storage)
    /// 4. Bundle plist (development only, if exists)
    func getAPIKey(for service: String) -> String? {
        // Priority 1: Environment variables (for production)
        if let envKey = ProcessInfo.processInfo.environment[service.uppercased().replacingOccurrences(of: " ", with: "_")] {
            print("🔐 Using environment variable for \(service)")
            return envKey
        }
        
        // Priority 2: Try keychain storage
        if let keychainKey = KeychainManager.shared.getAPIKey(forService: service) {
            print("🔐 Using keychain storage for \(service)")
            return keychainKey
        }
        
        // Priority 3: Development fallback - bundle plist (if exists)
        #if DEBUG
        if let bundleKey = getBundleAPIKey(for: service) {
            print("🔐 Using bundle plist for \(service) (DEBUG only)")
            return bundleKey
        }
        #endif
        
        print("❌ No API key found for service: \(service)")
        return nil
    }
    
    /// Development-only: Load from bundle plist if available
    private func getBundleAPIKey(for service: String) -> String? {
        guard let path = Bundle.main.path(forResource: "api_keys", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist[service] as? String,
              !apiKey.isEmpty,
              !apiKey.contains("YOUR_") else {
            return nil
        }
        return apiKey
    }
    
    /// Store API key securely in keychain
    func storeAPIKey(_ key: String, for service: String) {
        do {
            try KeychainManager.shared.storeAPIKey(key, forService: service)
            print("✅ API key stored securely for \(service)")
        } catch {
            print("❌ Failed to store API key for \(service): \(error)")
        }
    }
    
    /// Remove API key from secure storage
    func removeAPIKey(for service: String) {
        do {
            try KeychainManager.shared.deleteAPIKey(forService: service)
            print("✅ API key removed for \(service)")
        } catch {
            print("❌ Failed to remove API key for \(service): \(error)")
        }
    }
    
    /// Validate that all required API keys are available
    func validateRequiredKeys() -> Bool {
        let requiredServices = ["GoogleTranslateAPIKey", "FirebaseAPIKey"]
        
        for service in requiredServices {
            guard getAPIKey(for: service) != nil else {
                print("❌ Missing required API key: \(service)")
                return false
            }
        }
        
        print("✅ All required API keys are available")
        return true
    }
    
    /// Get Firebase configuration from environment or bundle
    func getFirebaseConfig() -> [String: Any]? {
        // Priority 1: Environment variables for production
        if let projectId = ProcessInfo.processInfo.environment["FIREBASE_PROJECT_ID"],
           let apiKey = ProcessInfo.processInfo.environment["FIREBASE_API_KEY"] {
            return [
                "PROJECT_ID": projectId,
                "API_KEY": apiKey,
                "BUNDLE_ID": Bundle.main.bundleIdentifier ?? "com.universaltranslator.app"
            ]
        }
        
        // Priority 2: Bundle configuration (development)
        #if DEBUG
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) as? [String: Any] {
            print("🔐 Using bundle Firebase config (DEBUG only)")
            return plist
        }
        #endif
        
        print("❌ No Firebase configuration found")
        return nil
    }
}

/// Extension for easy access to common API keys
extension SecureConfig {
    var googleTranslateAPIKey: String? {
        return getAPIKey(for: "GoogleTranslateAPIKey")
    }
    
    var firebaseAPIKey: String? {
        return getAPIKey(for: "FirebaseAPIKey")
    }
}
