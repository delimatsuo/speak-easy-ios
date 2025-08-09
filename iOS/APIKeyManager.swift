//
//  APIKeyManager.swift
//  Mervyn Talks
//
//  Manages API key storage and retrieval
//

import Foundation

class APIKeyManager {
    static let shared = APIKeyManager()
    
    private let keychainService = "GoogleTranslateAPIKey"
    private let userDefaultsKey = "hasStoredAPIKey"
    
    // API keys are now loaded from secure plist file
    private var cachedAPIKey: String?
    
    private init() {
        setupAPIKeyIfNeeded()
    }
    
    /// Initialize API key storage on first launch
    private func setupAPIKeyIfNeeded() {
        // Load API key from plist and store in keychain if needed
        guard let apiKey = loadAPIKeyFromPlist() else {
            print("❌ No API key found in plist file")
            return
        }
        
        // Check if we've already stored the key
        let hasStoredKey = UserDefaults.standard.bool(forKey: userDefaultsKey)
        
        if !hasStoredKey {
            do {
                // Store the API key in keychain
                try KeychainManager.shared.storeAPIKey(apiKey, forService: keychainService)
                UserDefaults.standard.set(true, forKey: userDefaultsKey)
                print("✅ API key stored successfully in Keychain")
            } catch {
                print("❌ Failed to store API key: \(error)")
            }
        }
        
        cachedAPIKey = apiKey
    }
    
    /// Load API key from secure plist file
    private func loadAPIKeyFromPlist() -> String? {
        guard let path = Bundle.main.path(forResource: "api_keys", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            // Do not spam logs if file is missing; backend uses Secret Manager
            return nil
        }
        // Accept multiple common keys for resilience
        let possibleKeys = [keychainService, "GoogleTranslateAPIKey", "X-API-Key", "API_KEY"]
        for k in possibleKeys {
            if let value = plist[k] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !value.contains("YOUR_") {
                return value
            }
        }
        // Silent if empty; not required for normal operation
        return nil
    }
    
    /// Get the API key from secure storage
    func getAPIKey() -> String? {
        // Return cached key if available
        if let cachedKey = cachedAPIKey {
            return cachedKey
        }
        
        // First try to get from keychain
        if let key = KeychainManager.shared.getAPIKey(forService: keychainService) {
            cachedAPIKey = key
            return key
        }
        
        // If not in keychain, try to load from plist and store
        guard let apiKey = loadAPIKeyFromPlist() else {
            print("❌ No API key available from any source")
            return nil
        }
        
        // Store in keychain for future use
        do {
            try KeychainManager.shared.storeAPIKey(apiKey, forService: keychainService)
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            cachedAPIKey = apiKey
            return apiKey
        } catch {
            print("❌ Failed to store API key in keychain: \(error)")
            // Still return the key from plist
            cachedAPIKey = apiKey
            return apiKey
        }
    }
    
    /// Force refresh the API key (useful for updates)
    func refreshAPIKey() {
        // Clear cache
        cachedAPIKey = nil
        
        // Load fresh from plist
        guard let apiKey = loadAPIKeyFromPlist() else {
            print("❌ No API key found in plist for refresh")
            return
        }
        
        do {
            try KeychainManager.shared.storeAPIKey(apiKey, forService: keychainService)
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            cachedAPIKey = apiKey
            print("✅ API key refreshed successfully")
        } catch {
            print("❌ Failed to refresh API key: \(error)")
        }
    }
    
    /// Check if API key is properly configured
    func isAPIKeyConfigured() -> Bool {
        return getAPIKey() != nil
    }
}