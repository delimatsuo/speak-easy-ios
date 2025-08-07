//
//  KeychainManager.swift
//  Speak Easy
//
//  Created on 2025-08-05
//

import Foundation
import Security

/// Secure API key management using the iOS Keychain
class KeychainManager {
    
    static let shared = KeychainManager()
    
    private init() {}
    
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidItemFormat
        case unexpectedStatus(OSStatus)
    }
    
    /// Store API key securely in Keychain
    func storeAPIKey(_ key: String, forService service: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        
        // Create query for Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Retrieve API key from Keychain
    func retrieveAPIKey(forService service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = dataTypeRef as? Data, 
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        
        return key
    }
    
    /// Delete API key from Keychain
    func deleteAPIKey(forService service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Load API key from bundle during development, or keychain in production
    func getAPIKey(forService service: String) -> String? {
        #if DEBUG
        // In debug mode, try to load from plist
        if let path = Bundle.main.path(forResource: "api_keys", ofType: "plist"),
           let keys = NSDictionary(contentsOfFile: path),
           let key = keys[service] as? String {
            return key
        }
        #endif
        
        // In production or if plist fails, try keychain
        do {
            return try retrieveAPIKey(forService: service)
        } catch {
            print("Failed to retrieve API key: \(error)")
            return nil
        }
    }
}
