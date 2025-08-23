//
//  SecureEncryption.swift
//  UniversalTranslator
//
//  Advanced encryption service with AES-256-GCM, key derivation,
//  secure key storage, and comprehensive security measures.
//

import Foundation
import CryptoKit
import Security

// MARK: - Encryption Errors

enum EncryptionError: Error, LocalizedError {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidData
    case invalidKey
    case keyDerivationFailed
    case keychainError(OSStatus)
    case invalidNonce
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .encryptionFailed:
            return "Encryption operation failed"
        case .decryptionFailed:
            return "Decryption operation failed"
        case .invalidData:
            return "Invalid data format"
        case .invalidKey:
            return "Invalid encryption key"
        case .keyDerivationFailed:
            return "Key derivation failed"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .invalidNonce:
            return "Invalid nonce"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
}

// MARK: - Encrypted Data Container

struct EncryptedData {
    let ciphertext: Data
    let nonce: Data
    let salt: Data?
    let tag: Data
    
    func serialize() -> Data {
        var result = Data()
        
        // Add lengths as 4-byte integers
        result += withUnsafeBytes(of: UInt32(ciphertext.count).bigEndian) { Data($0) }
        result += withUnsafeBytes(of: UInt32(nonce.count).bigEndian) { Data($0) }
        result += withUnsafeBytes(of: UInt32(salt?.count ?? 0).bigEndian) { Data($0) }
        result += withUnsafeBytes(of: UInt32(tag.count).bigEndian) { Data($0) }
        
        // Add data
        result += ciphertext
        result += nonce
        if let salt = salt {
            result += salt
        }
        result += tag
        
        return result
    }
    
    static func deserialize(_ data: Data) throws -> EncryptedData {
        guard data.count >= 16 else { throw EncryptionError.invalidData }
        
        var offset = 0
        
        // Read lengths
        let ciphertextLength = Int(data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        offset += 4
        
        let nonceLength = Int(data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        offset += 4
        
        let saltLength = Int(data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        offset += 4
        
        let tagLength = Int(data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
        offset += 4
        
        // Read data
        guard offset + ciphertextLength + nonceLength + saltLength + tagLength <= data.count else {
            throw EncryptionError.invalidData
        }
        
        let ciphertext = data.subdata(in: offset..<offset+ciphertextLength)
        offset += ciphertextLength
        
        let nonce = data.subdata(in: offset..<offset+nonceLength)
        offset += nonceLength
        
        let salt = saltLength > 0 ? data.subdata(in: offset..<offset+saltLength) : nil
        offset += saltLength
        
        let tag = data.subdata(in: offset..<offset+tagLength)
        
        return EncryptedData(ciphertext: ciphertext, nonce: nonce, salt: salt, tag: tag)
    }
}

// MARK: - Secure Encryption Service

class SecureEncryption {
    static let shared = SecureEncryption()
    
    private let keySize = 32 // AES-256
    private let nonceSize = 12 // AES-GCM standard
    private let saltSize = 16
    private let tagSize = 16
    private let iterations = 100_000 // PBKDF2 iterations
    
    private init() {}
    
    // MARK: - Key Management
    
    /// Generate a cryptographically secure random key
    func generateKey() throws -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    /// Derive key from password using PBKDF2
    func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        var derivedKey = Data(count: keySize)
        let result = derivedKey.withUnsafeMutableBytes { keyBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordData.withUnsafeBytes { $0.bindMemory(to: Int8.self).baseAddress },
                    passwordData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    keyBytes.bindMemory(to: UInt8.self).baseAddress,
                    keySize
                )
            }
        }
        
        guard result == kCCSuccess else {
            throw EncryptionError.keyDerivationFailed
        }
        
        return SymmetricKey(data: derivedKey)
    }
    
    /// Generate cryptographically secure salt
    func generateSalt() -> Data {
        var salt = Data(count: saltSize)
        salt.withUnsafeMutableBytes { bytes in
            let result = SecRandomCopyBytes(kSecRandomDefault, saltSize, bytes.bindMemory(to: UInt8.self).baseAddress!)
            assert(result == errSecSuccess)
        }
        return salt
    }
    
    // MARK: - Encryption/Decryption
    
    /// Encrypt data using AES-256-GCM
    func encrypt(_ data: Data, with key: SymmetricKey) throws -> EncryptedData {
        guard !data.isEmpty else {
            throw EncryptionError.invalidData
        }
        
        // Generate random nonce
        let nonce = AES.GCM.Nonce()
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
            
            guard let ciphertext = sealedBox.ciphertext,
                  let tag = sealedBox.tag else {
                throw EncryptionError.encryptionFailed
            }
            
            return EncryptedData(
                ciphertext: ciphertext,
                nonce: Data(nonce),
                salt: nil,
                tag: tag
            )
        } catch {
            throw EncryptionError.encryptionFailed
        }
    }
    
    /// Encrypt data with password (includes key derivation)
    func encrypt(_ data: Data, with password: String) throws -> EncryptedData {
        let salt = generateSalt()
        let key = try deriveKey(from: password, salt: salt)
        let encrypted = try encrypt(data, with: key)
        
        return EncryptedData(
            ciphertext: encrypted.ciphertext,
            nonce: encrypted.nonce,
            salt: salt,
            tag: encrypted.tag
        )
    }
    
    /// Decrypt data using AES-256-GCM
    func decrypt(_ encryptedData: EncryptedData, with key: SymmetricKey) throws -> Data {
        do {
            let nonce = try AES.GCM.Nonce(data: encryptedData.nonce)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: encryptedData.ciphertext,
                tag: encryptedData.tag
            )
            
            return try AES.GCM.open(sealedBox, using: key)
        } catch CryptoKitError.authenticationFailure {
            throw EncryptionError.authenticationFailed
        } catch {
            throw EncryptionError.decryptionFailed
        }
    }
    
    /// Decrypt data with password
    func decrypt(_ encryptedData: EncryptedData, with password: String) throws -> Data {
        guard let salt = encryptedData.salt else {
            throw EncryptionError.invalidData
        }
        
        let key = try deriveKey(from: password, salt: salt)
        return try decrypt(encryptedData, with: key)
    }
    
    // MARK: - Keychain Integration
    
    /// Store key securely in Keychain
    func storeKey(_ key: SymmetricKey, withIdentifier identifier: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "SecureEncryption",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing key first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError(status)
        }
    }
    
    /// Retrieve key from Keychain
    func retrieveKey(withIdentifier identifier: String) throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "SecureEncryption",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let keyData = result as? Data else {
            throw EncryptionError.keychainError(status)
        }
        
        return SymmetricKey(data: keyData)
    }
    
    /// Delete key from Keychain
    func deleteKey(withIdentifier identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecAttrService as String: "SecureEncryption"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EncryptionError.keychainError(status)
        }
    }
    
    // MARK: - Utility Methods
    
    /// Generate cryptographically secure random data
    func generateRandomData(length: Int) -> Data {
        var data = Data(count: length)
        data.withUnsafeMutableBytes { bytes in
            let result = SecRandomCopyBytes(kSecRandomDefault, length, bytes.bindMemory(to: UInt8.self).baseAddress!)
            assert(result == errSecSuccess)
        }
        return data
    }
    
    /// Hash data using SHA-256
    func hash(_ data: Data) -> Data {
        return Data(SHA256.hash(data: data))
    }
    
    /// Constant-time comparison for security
    func constantTimeCompare(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        
        var result: UInt8 = 0
        for i in 0..<lhs.count {
            result |= lhs[i] ^ rhs[i]
        }
        return result == 0
    }
    
    /// Secure memory wipe
    func secureWipe(_ data: inout Data) {
        data.withUnsafeMutableBytes { bytes in
            memset_s(bytes.baseAddress, bytes.count, 0, bytes.count)
        }
    }
}

// MARK: - Convenience Extensions

extension SecureEncryption {
    /// Encrypt string with password
    func encrypt(_ string: String, with password: String) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        let encrypted = try encrypt(data, with: password)
        return encrypted.serialize()
    }
    
    /// Decrypt string with password
    func decryptString(_ data: Data, with password: String) throws -> String {
        let encrypted = try EncryptedData.deserialize(data)
        let decrypted = try decrypt(encrypted, with: password)
        
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.invalidData
        }
        return string
    }
}

// MARK: - PBKDF2 Helper (for compatibility)

private func CCKeyDerivationPBKDF(
    _ algorithm: CCPBKDFAlgorithm,
    _ password: UnsafePointer<Int8>?,
    _ passwordLen: Int,
    _ salt: UnsafePointer<UInt8>?,
    _ saltLen: Int,
    _ prf: CCPseudoRandomAlgorithm,
    _ rounds: UInt32,
    _ derivedKey: UnsafeMutablePointer<UInt8>?,
    _ derivedKeyLen: Int
) -> Int32 {
    return CCKeyDerivationPBKDF(
        algorithm,
        password,
        passwordLen,
        salt,
        saltLen,
        prf,
        rounds,
        derivedKey,
        derivedKeyLen
    )
}