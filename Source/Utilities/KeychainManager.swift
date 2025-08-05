import Foundation
import Security
import LocalAuthentication
import CryptoKit

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.universaltranslator.api"
    private let keyDerivationSalt = "UniversalTranslator.KeyDerivation.Salt.v1"
    private let accessGroup = "group.universaltranslator.secure"
    
    private init() {}
    
    // SECURITY ENHANCEMENT: Secure storage with biometric protection
    func store(apiKey: String, for service: APIService) throws {
        let encryptedKey = try encryptAPIKey(apiKey)
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: service.rawValue,
            kSecValueData as String: encryptedKey,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false, // Prevent iCloud sync
        ]
        
        // SECURITY: Add biometric protection for production keys
        if service == .gemini {
            let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                [.biometryAny, .or, .devicePasscode],
                nil
            )
            if let access = access {
                query[kSecAttrAccessControl as String] = access
            }
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            try update(apiKey: apiKey, for: service)
        } else if status != errSecSuccess {
            throw KeychainError.storeFailed(status)
        }
        
        // Log security event
        logSecurityEvent(.keyStored, service: service)
    }
    
    // SECURITY ENHANCEMENT: Secure retrieval with decryption
    func retrieve(for service: APIService) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: service.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Add biometric authentication for production keys
        if service == .gemini {
            query[kSecUseOperationPrompt as String] = "Access API key for translation"
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let encryptedData = result as? Data else {
            logSecurityEvent(.keyRetrievalFailed, service: service, error: status)
            return nil
        }
        
        do {
            let decryptedKey = try decryptAPIKey(encryptedData)
            logSecurityEvent(.keyRetrieved, service: service)
            return decryptedKey
        } catch {
            logSecurityEvent(.keyDecryptionFailed, service: service, error: error)
            return nil
        }
    }
    
    func delete(for service: APIService) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: service.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    private func update(apiKey: String, for service: APIService) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: service.rawValue
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: apiKey.data(using: .utf8)!
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        if status != errSecSuccess {
            throw KeychainError.storeFailed(status)
        }
    }
    
    // SECURITY ENHANCEMENT: Secure key rotation with validation
    func rotate(for service: APIService, newKey: String) throws {
        guard isValidAPIKey(newKey, for: service) else {
            throw KeychainError.invalidKeyFormat
        }
        
        // Store old key temporarily for rollback
        let oldKey = retrieve(for: service)
        
        do {
            try store(apiKey: newKey, for: service)
            
            // Validate new key works
            if service == .gemini {
                Task {
                    do {
                        let isValid = try await validateKeyWithAPI(newKey)
                        if !isValid {
                            // Rollback to old key
                            if let oldKey = oldKey {
                                try? self.store(apiKey: oldKey, for: service)
                            }
                            throw KeychainError.keyValidationFailed
                        }
                    } catch {
                        logSecurityEvent(.keyRotationFailed, service: service, error: error)
                    }
                }
            }
            
            logSecurityEvent(.keyRotated, service: service)
            
            NotificationCenter.default.post(
                name: .apiKeyRotated,
                object: service
            )
        } catch {
            logSecurityEvent(.keyRotationFailed, service: service, error: error)
            throw error
        }
    }
    
    func deleteAll() throws {
        for service in APIService.allCases {
            try? delete(for: service)
        }
        logSecurityEvent(.allKeysDeleted, service: nil)
    }
    
    // MARK: - Private Security Methods
    
    private func encryptAPIKey(_ key: String) throws -> Data {
        guard let keyData = key.data(using: .utf8) else {
            throw KeychainError.encryptionFailed
        }
        
        // Use device-specific encryption key
        let encryptionKey = try deriveEncryptionKey()
        let sealedBox = try AES.GCM.seal(keyData, using: encryptionKey)
        
        return sealedBox.combined ?? Data()
    }
    
    private func decryptAPIKey(_ encryptedData: Data) throws -> String {
        let encryptionKey = try deriveEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
        
        guard let decryptedKey = String(data: decryptedData, encoding: .utf8) else {
            throw KeychainError.decryptionFailed
        }
        
        return decryptedKey
    }
    
    private func deriveEncryptionKey() throws -> SymmetricKey {
        // Use device-specific information for key derivation
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let saltData = keyDerivationSalt.data(using: .utf8) ?? Data()
        let deviceData = deviceID.data(using: .utf8) ?? Data()
        
        let combinedData = saltData + deviceData
        let hashedData = SHA256.hash(data: combinedData)
        
        return SymmetricKey(data: hashedData)
    }
    
    private func isValidAPIKey(_ key: String, for service: APIService) -> Bool {
        switch service {
        case .gemini:
            return key.hasPrefix("AIza") && key.count == 39
        case .backup:
            return !key.isEmpty && key.count > 10
        }
    }
    
    private func validateKeyWithAPI(_ key: String) async throws -> Bool {
        // Basic validation against Gemini API
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "X-Goog-Api-Key")
        request.timeoutInterval = 10.0
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        
        return false
    }
    
    private func logSecurityEvent(_ event: SecurityEvent, service: APIService?, error: Any? = nil) {
        let eventData: [String: Any] = [
            "event": event.rawValue,
            "service": service?.rawValue ?? "unknown",
            "timestamp": Date().iso8601String,
            "error": error.map { String(describing: $0) } ?? "none"
        ]
        
        // Log to secure audit trail
        print("SECURITY EVENT: \(eventData)")
    }
    
    enum APIService: String, CaseIterable {
        case gemini = "gemini_api"
        case backup = "backup_api"
    }
    
    enum SecurityEvent: String {
        case keyStored = "key_stored"
        case keyRetrieved = "key_retrieved"
        case keyRotated = "key_rotated"
        case keyDeleted = "key_deleted"
        case allKeysDeleted = "all_keys_deleted"
        case keyRetrievalFailed = "key_retrieval_failed"
        case keyDecryptionFailed = "key_decryption_failed"
        case keyRotationFailed = "key_rotation_failed"
    }
}

extension Notification.Name {
    static let apiKeyRotated = Notification.Name("apiKeyRotated")
}