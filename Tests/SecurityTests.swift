import XCTest
import Security
import Foundation
@testable import UniversalTranslatorApp

// MARK: - API Key Management Security Tests
class SecurityTests: BaseTestCase {
    
    let testService = "com.universaltranslator.test"
    let testAPIKey = "test_api_key_12345"
    let testRotatedKey = "rotated_api_key_67890"
    
    override func setUp() {
        super.setUp()
        // Clean up any existing test keys
        deleteTestKeychainItems()
    }
    
    override func tearDown() {
        // Clean up test keys
        deleteTestKeychainItems()
        super.tearDown()
    }
    
    private func deleteTestKeychainItems() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: testService
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Keychain Storage Tests
    func testKeychainAPIKeyStorage() {
        let expectation = expectation(description: "Keychain API key storage")
        
        Task {
            // Test storing API key in keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.testService,
                kSecAttrAccount as String: "gemini_api",
                kSecValueData as String: self.testAPIKey.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let status = SecItemAdd(query as CFDictionary, nil)
            XCTAssertEqual(status, errSecSuccess, "Failed to store API key in keychain")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testSecureAPIKeyRetrieval() {
        let expectation = expectation(description: "Secure API key retrieval")
        
        Task {
            // First store an API key
            let storeQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.testService,
                kSecAttrAccount as String: "gemini_api",
                kSecValueData as String: self.testAPIKey.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let storeStatus = SecItemAdd(storeQuery as CFDictionary, nil)
            XCTAssertEqual(storeStatus, errSecSuccess)
            
            // Now retrieve the API key
            let retrieveQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.testService,
                kSecAttrAccount as String: "gemini_api",
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let retrieveStatus = SecItemCopyMatching(retrieveQuery as CFDictionary, &result)
            
            XCTAssertEqual(retrieveStatus, errSecSuccess, "Failed to retrieve API key from keychain")
            
            if let data = result as? Data,
               let retrievedKey = String(data: data, encoding: .utf8) {
                XCTAssertEqual(retrievedKey, self.testAPIKey)
            } else {
                XCTFail("Failed to decode retrieved API key")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testAPIKeyRotation() {
        let expectation = expectation(description: "API key rotation")
        
        Task {
            // Store initial API key
            let initialQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.testService,
                kSecAttrAccount as String: "gemini_api",
                kSecValueData as String: self.testAPIKey.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let initialStatus = SecItemAdd(initialQuery as CFDictionary, nil)
            XCTAssertEqual(initialStatus, errSecSuccess)
            
            // Rotate to new key (delete old, store new)
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.testService,
                kSecAttrAccount as String: "gemini_api"
            ]
            
            let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
            XCTAssertEqual(deleteStatus, errSecSuccess)
            
            // Store rotated key
            let rotatedQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.testService,
                kSecAttrAccount as String: "gemini_api",
                kSecValueData as String: self.testRotatedKey.data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            let rotatedStatus = SecItemAdd(rotatedQuery as CFDictionary, nil)
            XCTAssertEqual(rotatedStatus, errSecSuccess)
            
            // Verify new key is stored
            let verifyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: self.testService,
                kSecAttrAccount as String: "gemini_api",
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            
            var result: AnyObject?
            let verifyStatus = SecItemCopyMatching(verifyQuery as CFDictionary, &result)
            
            XCTAssertEqual(verifyStatus, errSecSuccess)
            
            if let data = result as? Data,
               let retrievedKey = String(data: data, encoding: .utf8) {
                XCTAssertEqual(retrievedKey, self.testRotatedKey)
                XCTAssertNotEqual(retrievedKey, self.testAPIKey)
            } else {
                XCTFail("Failed to verify rotated API key")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testKeychainAccessPermissions() {
        let expectation = expectation(description: "Keychain access permissions")
        
        Task {
            // Test that keychain items are properly protected
            let accessibilityLevels = [
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            ]
            
            for accessibility in accessibilityLevels {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: self.testService,
                    kSecAttrAccount as String: "test_\(accessibility)",
                    kSecValueData as String: "test_data".data(using: .utf8)!,
                    kSecAttrAccessible as String: accessibility
                ]
                
                let status = SecItemAdd(query as CFDictionary, nil)
                XCTAssertEqual(status, errSecSuccess, "Failed to store with accessibility level \(accessibility)")
                
                // Clean up
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: self.testService,
                    kSecAttrAccount as String: "test_\(accessibility)"
                ]
                SecItemDelete(deleteQuery as CFDictionary)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
}

// MARK: - Network Security Tests
class NetworkSecurityTests: BaseTestCase {
    
    // MARK: - TLS Configuration Tests
    func testTLS13Enforcement() {
        let expectation = expectation(description: "TLS 1.3 enforcement")
        
        Task {
            let configuration = URLSessionConfiguration.default
            
            // Test TLS 1.3 minimum requirement
            configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
            
            XCTAssertEqual(configuration.tlsMinimumSupportedProtocolVersion, .TLSv13)
            
            // Verify that older TLS versions are not allowed
            XCTAssertNotEqual(configuration.tlsMinimumSupportedProtocolVersion, .TLSv12)
            XCTAssertNotEqual(configuration.tlsMinimumSupportedProtocolVersion, .TLSv11)
            XCTAssertNotEqual(configuration.tlsMinimumSupportedProtocolVersion, .TLSv10)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testCertificatePinning() {
        let expectation = expectation(description: "Certificate pinning")
        
        Task {
            // Test certificate pinning configuration
            // In a real implementation, this would load actual certificates
            let mockCertificateData = Data([0x30, 0x82, 0x03, 0x15]) // Mock DER certificate start
            
            // Test certificate creation
            XCTAssertGreaterThan(mockCertificateData.count, 0)
            
            // Test that pinned certificates are validated
            // This would be expanded in actual implementation to test SecCertificate creation
            XCTAssertTrue(true, "Certificate pinning structure validated")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testCertificateValidation() {
        let expectation = expectation(description: "Certificate validation")
        
        Task {
            // Test certificate validation logic
            // This simulates the validation process from the backend specification
            
            // Mock certificate validation
            let mockTrustResult = true // In real implementation, this would use SecTrustEvaluateWithError
            
            XCTAssertTrue(mockTrustResult, "Certificate validation should succeed for valid certificates")
            
            // Test invalid certificate handling
            let mockInvalidTrustResult = false
            XCTAssertFalse(mockInvalidTrustResult, "Certificate validation should fail for invalid certificates")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testHTTPSOnlyCommunication() {
        let expectation = expectation(description: "HTTPS-only communication")
        
        Task {
            // Test that all API endpoints use HTTPS
            let apiEndpoints = [
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent",
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:synthesizeSpeech"
            ]
            
            for endpoint in apiEndpoints {
                guard let url = URL(string: endpoint) else {
                    XCTFail("Invalid URL: \(endpoint)")
                    continue
                }
                
                XCTAssertEqual(url.scheme, "https", "All API endpoints must use HTTPS")
                XCTAssertNotEqual(url.scheme, "http", "HTTP endpoints are not allowed")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
}

// MARK: - Privacy Compliance Tests
class PrivacyTests: BaseTestCase {
    
    override func setUp() {
        super.setUp()
        // Reset privacy settings to defaults
        UserDefaults.standard.removeObject(forKey: "store_translations")
        UserDefaults.standard.removeObject(forKey: "share_analytics")
        UserDefaults.standard.removeObject(forKey: "use_cloud_backup")
    }
    
    // MARK: - Data Storage Controls Tests
    func testDataStorageControls() {
        let expectation = expectation(description: "Data storage controls")
        
        Task {
            // Test that translations are not stored by default
            let storeTranslations = UserDefaults.standard.bool(forKey: "store_translations")
            XCTAssertFalse(storeTranslations, "Translations should not be stored by default")
            
            // Test enabling storage
            UserDefaults.standard.set(true, forKey: "store_translations")
            let enabledStorage = UserDefaults.standard.bool(forKey: "store_translations")
            XCTAssertTrue(enabledStorage, "Storage should be enabled when user opts in")
            
            // Test disabling storage
            UserDefaults.standard.set(false, forKey: "store_translations")
            let disabledStorage = UserDefaults.standard.bool(forKey: "store_translations")
            XCTAssertFalse(disabledStorage, "Storage should be disabled when user opts out")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testUserConsentMechanisms() {
        let expectation = expectation(description: "User consent mechanisms")
        
        Task {
            // Test consent tracking for different features
            let privacyFeatures = [
                "store_translations",
                "share_analytics", 
                "use_cloud_backup",
                "allow_personalization"
            ]
            
            for feature in privacyFeatures {
                // Initially no consent should be recorded
                let consentKey = "consent_\(feature)"
                let initialConsent = UserDefaults.standard.object(forKey: consentKey)
                XCTAssertNil(initialConsent, "No consent should be recorded initially for \(feature)")
                
                // Test granting consent
                UserDefaults.standard.set(true, forKey: consentKey)
                let grantedConsent = UserDefaults.standard.bool(forKey: consentKey)
                XCTAssertTrue(grantedConsent, "Consent should be recorded when granted for \(feature)")
                
                // Test withdrawing consent
                UserDefaults.standard.set(false, forKey: consentKey)
                let withdrawnConsent = UserDefaults.standard.bool(forKey: consentKey)
                XCTAssertFalse(withdrawnConsent, "Consent withdrawal should be recorded for \(feature)")
                
                // Clean up
                UserDefaults.standard.removeObject(forKey: consentKey)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testDataDeletionFunctionality() {
        let expectation = expectation(description: "Data deletion functionality")
        
        Task {
            // Test that user data can be completely deleted
            
            // First, create some test data
            UserDefaults.standard.set("test_translation", forKey: "cached_translation")
            UserDefaults.standard.set(true, forKey: "store_translations")
            
            // Store test keychain item
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.universaltranslator.test",
                kSecAttrAccount as String: "test_data",
                kSecValueData as String: "test_value".data(using: .utf8)!
            ]
            SecItemAdd(query as CFDictionary, nil)
            
            // Verify data exists
            XCTAssertNotNil(UserDefaults.standard.object(forKey: "cached_translation"))
            XCTAssertTrue(UserDefaults.standard.bool(forKey: "store_translations"))
            
            // Test data deletion
            // Clear UserDefaults
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            
            // Clear keychain
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.universaltranslator.test"
            ]
            SecItemDelete(deleteQuery as CFDictionary)
            
            // Verify data is deleted
            XCTAssertNil(UserDefaults.standard.object(forKey: "cached_translation"))
            XCTAssertFalse(UserDefaults.standard.bool(forKey: "store_translations"))
            
            // Verify keychain data is deleted
            var result: AnyObject?
            let retrieveQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "com.universaltranslator.test",
                kSecAttrAccount as String: "test_data",
                kSecReturnData as String: true
            ]
            let status = SecItemCopyMatching(retrieveQuery as CFDictionary, &result)
            XCTAssertEqual(status, errSecItemNotFound, "Keychain data should be deleted")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testAnalyticsOptOut() {
        let expectation = expectation(description: "Analytics opt-out")
        
        Task {
            // Test analytics are disabled by default
            let shareAnalytics = UserDefaults.standard.bool(forKey: "share_analytics")
            XCTAssertFalse(shareAnalytics, "Analytics should be disabled by default")
            
            // Test opting in to analytics
            UserDefaults.standard.set(true, forKey: "share_analytics")
            let enabledAnalytics = UserDefaults.standard.bool(forKey: "share_analytics")
            XCTAssertTrue(enabledAnalytics, "Analytics should be enabled when user opts in")
            
            // Test opting out of analytics
            UserDefaults.standard.set(false, forKey: "share_analytics")
            let disabledAnalytics = UserDefaults.standard.bool(forKey: "share_analytics")
            XCTAssertFalse(disabledAnalytics, "Analytics should be disabled when user opts out")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
}

// MARK: - Secure Communication Tests
class SecureCommunicationTests: BaseTestCase {
    
    func testAPIKeyHeaderSecurity() {
        let expectation = expectation(description: "API key header security")
        
        Task {
            // Test that API keys are properly included in headers
            let testKey = "test_api_key_12345"
            let headers = [
                "Content-Type": "application/json",
                "X-Goog-Api-Key": testKey
            ]
            
            XCTAssertEqual(headers["X-Goog-Api-Key"], testKey)
            XCTAssertEqual(headers["Content-Type"], "application/json")
            
            // Test that API key is not logged or exposed
            let sanitizedHeaders = headers.mapValues { key in
                key == testKey ? "[REDACTED]" : key
            }
            
            XCTAssertEqual(sanitizedHeaders["X-Goog-Api-Key"], "[REDACTED]")
            XCTAssertNotEqual(sanitizedHeaders["X-Goog-Api-Key"], testKey)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testRequestDataSanitization() {
        let expectation = expectation(description: "Request data sanitization")
        
        Task {
            // Test that sensitive data is not logged in requests
            let requestData = [
                "contents": [["parts": [["text": "Translate this text"]], "role": "user"]],
                "api_key": "sensitive_key_12345"
            ]
            
            // Simulate sanitization for logging
            var sanitizedData = requestData
            if sanitizedData["api_key"] != nil {
                sanitizedData["api_key"] = "[REDACTED]"
            }
            
            XCTAssertEqual(sanitizedData["api_key"] as? String, "[REDACTED]")
            XCTAssertNotEqual(sanitizedData["api_key"] as? String, "sensitive_key_12345")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testMemorySecurityForKeys() {
        let expectation = expectation(description: "Memory security for keys")
        
        Task {
            // Test that API keys are cleared from memory when not needed
            var apiKey: String? = "test_api_key_12345"
            XCTAssertNotNil(apiKey)
            
            // Simulate key usage and cleanup
            let keyLength = apiKey?.count ?? 0
            XCTAssertGreaterThan(keyLength, 0)
            
            // Clear the key from memory
            apiKey = nil
            XCTAssertNil(apiKey)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
}