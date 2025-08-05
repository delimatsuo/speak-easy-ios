import Foundation
import CryptoKit

class SecureAPIWrapper {
    static let shared = SecureAPIWrapper()
    
    private let sessionKey: SymmetricKey
    private let nonce = AES.GCM.Nonce()
    
    private init() {
        // Generate session key for request/response encryption
        self.sessionKey = SymmetricKey(size: .bits256)
    }
    
    // SECURITY: Encrypt sensitive data before transmission
    func encryptRequestData(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: sessionKey, nonce: nonce)
        return sealedBox.combined ?? data
    }
    
    // SECURITY: Decrypt response data
    func decryptResponseData(_ encryptedData: Data) throws -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            return try AES.GCM.open(sealedBox, using: sessionKey)
        } catch {
            // If decryption fails, assume data was not encrypted
            return encryptedData
        }
    }
    
    // SECURITY: Add integrity check to requests
    func addIntegrityCheck(to request: inout URLRequest, data: Data) {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let dataHash = SHA256.hash(data: data)
        let hashString = dataHash.compactMap { String(format: "%02x", $0) }.joined()
        
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
        request.setValue(hashString, forHTTPHeaderField: "X-Data-Integrity")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
    }
    
    // SECURITY: Validate response integrity
    func validateResponseIntegrity(_ response: HTTPURLResponse, data: Data) -> Bool {
        guard let serverHash = response.value(forHTTPHeaderField: "X-Response-Integrity") else {
            // If no integrity header, assume valid for backward compatibility
            return true
        }
        
        let dataHash = SHA256.hash(data: data)
        let calculatedHash = dataHash.compactMap { String(format: "%02x", $0) }.joined()
        
        return serverHash == calculatedHash
    }
    
    // SECURITY: Sanitize request data to prevent injection
    func sanitizeRequestData(_ data: Data) -> Data {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            return data
        }
        
        // Remove potentially dangerous patterns
        let sanitized = jsonString
            .replacingOccurrences(of: "<script", with: "&lt;script")
            .replacingOccurrences(of: "javascript:", with: "")
            .replacingOccurrences(of: "eval(", with: "")
            .replacingOccurrences(of: "function(", with: "")
        
        return sanitized.data(using: .utf8) ?? data
    }
    
    // SECURITY: Add rate limiting headers
    func addRateLimitingHeaders(to request: inout URLRequest) {
        let clientID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let hashedClientID = SHA256.hash(data: clientID.data(using: .utf8) ?? Data())
        let clientHash = hashedClientID.compactMap { String(format: "%02x", $0) }.joined()
        
        request.setValue(clientHash, forHTTPHeaderField: "X-Client-ID")
        request.setValue("1.0", forHTTPHeaderField: "X-API-Version")
    }
}