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
    
    // The actual API key - this should be stored securely
    // For production, this should come from a secure configuration
    private let geminiAPIKey = "AIzaSyDftOOmdUoH5pMfiGoi4VuROetgh_gB5KQ"
    
    private init() {
        setupAPIKeyIfNeeded()
    }
    
    /// Initialize API key storage on first launch
    private func setupAPIKeyIfNeeded() {
        // Check if we've already stored the key
        let hasStoredKey = UserDefaults.standard.bool(forKey: userDefaultsKey)
        
        if !hasStoredKey {
            do {
                // Store the API key in keychain
                try KeychainManager.shared.storeAPIKey(geminiAPIKey, forService: keychainService)
                UserDefaults.standard.set(true, forKey: userDefaultsKey)
                print("✅ API key stored successfully in Keychain")
            } catch {
                print("❌ Failed to store API key: \(error)")
            }
        }
    }
    
    /// Get the API key from secure storage
    func getAPIKey() -> String? {
        // First try to get from keychain
        if let key = KeychainManager.shared.getAPIKey(forService: keychainService) {
            return key
        }
        
        // If not in keychain, store it and return
        do {
            try KeychainManager.shared.storeAPIKey(geminiAPIKey, forService: keychainService)
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            return geminiAPIKey
        } catch {
            print("❌ Failed to store/retrieve API key: \(error)")
            // Return the key anyway for development
            return geminiAPIKey
        }
    }
    
    /// Force refresh the API key (useful for updates)
    func refreshAPIKey() {
        do {
            try KeychainManager.shared.storeAPIKey(geminiAPIKey, forService: keychainService)
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            print("✅ API key refreshed successfully")
        } catch {
            print("❌ Failed to refresh API key: \(error)")
        }
    }
}