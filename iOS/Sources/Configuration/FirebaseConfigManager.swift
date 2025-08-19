//
//  FirebaseConfigManager.swift
//  Universal AI Translator
//
//  Secure Firebase configuration management
//

import Foundation
import Firebase

/// Manages Firebase configuration securely for different environments
class FirebaseConfigManager {
    static let shared = FirebaseConfigManager()
    
    private var isConfigured = false
    
    private init() {}
    
    /// Configure Firebase with secure environment-based settings
    func configure() {
        guard !isConfigured else {
            print("🔥 Firebase already configured")
            return
        }
        
        // Priority 1: Environment-based configuration (production)
        if let envConfig = getEnvironmentConfig() {
            configureWithEnvironment(envConfig)
            isConfigured = true
            return
        }
        
        // Priority 2: Bundle configuration (development)
        #if DEBUG
        if configureDevelopmentFirebase() {
            isConfigured = true
            return
        }
        #endif
        
        // Priority 3: Manual configuration with secure defaults
        configureWithDefaults()
        isConfigured = true
    }
    
    /// Get Firebase configuration from environment variables
    private func getEnvironmentConfig() -> [String: String]? {
        let env = ProcessInfo.processInfo.environment
        
        guard let projectId = env["FIREBASE_PROJECT_ID"],
              let apiKey = env["FIREBASE_API_KEY"],
              let bundleId = env["FIREBASE_BUNDLE_ID"] ?? Bundle.main.bundleIdentifier else {
            print("🔥 Environment Firebase config not found")
            return nil
        }
        
        print("🔥 Using environment Firebase configuration")
        
        return [
            "API_KEY": apiKey,
            "PROJECT_ID": projectId,
            "BUNDLE_ID": bundleId,
            "CLIENT_ID": env["FIREBASE_CLIENT_ID"] ?? "",
            "REVERSED_CLIENT_ID": env["FIREBASE_REVERSED_CLIENT_ID"] ?? "",
            "GCM_SENDER_ID": env["FIREBASE_GCM_SENDER_ID"] ?? "",
            "STORAGE_BUCKET": env["FIREBASE_STORAGE_BUCKET"] ?? "\(projectId).firebasestorage.app",
            "DATABASE_URL": env["FIREBASE_DATABASE_URL"] ?? "https://\(projectId)-default-rtdb.firebaseio.com/"
        ]
    }
    
    /// Configure Firebase with environment variables
    private func configureWithEnvironment(_ config: [String: String]) {
        guard let apiKey = config["API_KEY"],
              let projectId = config["PROJECT_ID"],
              let bundleId = config["BUNDLE_ID"] else {
            print("❌ Invalid environment Firebase configuration")
            return
        }
        
        // Create Firebase options programmatically
        let options = FirebaseOptions(
            googleAppID: config["CLIENT_ID"] ?? "\(projectId):ios:default",
            gcmSenderID: config["GCM_SENDER_ID"] ?? "000000000000"
        )
        
        options.apiKey = apiKey
        options.projectID = projectId
        options.bundleID = bundleId
        options.storageBucket = config["STORAGE_BUCKET"]
        options.databaseURL = config["DATABASE_URL"]
        
        FirebaseApp.configure(options: options)
        print("✅ Firebase configured with environment variables")
    }
    
    /// Development-only: Configure with bundle GoogleService-Info.plist
    #if DEBUG
    private func configureDevelopmentFirebase() -> Bool {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              FileManager.default.fileExists(atPath: path) else {
            print("🔥 No GoogleService-Info.plist found for development")
            return false
        }
        
        FirebaseApp.configure()
        print("✅ Firebase configured with development bundle")
        return true
    }
    #endif
    
    /// Configure with secure defaults for testing
    private func configureWithDefaults() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.universaltranslator.app"
        
        // Use minimal configuration for offline/testing scenarios
        let options = FirebaseOptions(
            googleAppID: "1:000000000000:ios:default",
            gcmSenderID: "000000000000"
        )
        
        options.apiKey = "test-api-key"
        options.projectID = "universal-translator-test"
        options.bundleID = bundleId
        
        FirebaseApp.configure(options: options)
        print("⚠️ Firebase configured with test defaults")
    }
    
    /// Validate Firebase configuration
    func validateConfiguration() -> Bool {
        guard let app = FirebaseApp.app() else {
            print("❌ Firebase not configured")
            return false
        }
        
        guard let options = app.options else {
            print("❌ Firebase options not available")
            return false
        }
        
        // Validate required fields
        let hasAPIKey = !options.apiKey.isEmpty && options.apiKey != "test-api-key"
        let hasProjectID = !options.projectID.isEmpty && options.projectID != "universal-translator-test"
        let hasBundleID = !options.bundleID.isEmpty
        
        let isValid = hasAPIKey && hasProjectID && hasBundleID
        
        if isValid {
            print("✅ Firebase configuration validated successfully")
        } else {
            print("⚠️ Firebase configuration validation failed - using test environment")
        }
        
        return isValid
    }
    
    /// Get current Firebase project ID
    var projectID: String? {
        return FirebaseApp.app()?.options.projectID
    }
    
    /// Check if running in production environment
    var isProductionEnvironment: Bool {
        guard let projectId = projectID else { return false }
        return projectId.contains("prod") || !projectId.contains("test")
    }
}
