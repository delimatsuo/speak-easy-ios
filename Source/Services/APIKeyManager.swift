import Foundation
import Security

class APIKeyManager {
    static let shared = APIKeyManager()
    
    private let keychainManager = KeychainManager.shared
    private let validator = APIKeyValidator()
    
    @Published var isConfigured: Bool = false
    @Published var lastValidationDate: Date?
    @Published var validationStatus: ValidationStatus = .unknown
    
    enum ValidationStatus {
        case unknown
        case valid
        case invalid
        case expired
        case rateLimited
        case networkError
    }
    
    private init() {
        checkConfiguration()
    }
    
    // MARK: - API Key Configuration
    
    func configureAPIKey(_ apiKey: String) async throws -> Bool {
        guard !apiKey.isEmpty else {
            throw APIKeyError.emptyKey
        }
        
        guard validateKeyFormat(apiKey) else {
            throw APIKeyError.invalidFormat
        }
        
        // Test the API key before storing
        let isValid = try await validator.validateKey(apiKey)
        guard isValid else {
            throw APIKeyError.authenticationFailed
        }
        
        // Store in keychain
        try keychainManager.store(apiKey: apiKey, for: .gemini)
        
        // Update status
        await MainActor.run {
            self.isConfigured = true
            self.lastValidationDate = Date()
            self.validationStatus = .valid
        }
        
        // Notify other components
        NotificationCenter.default.post(name: .apiKeyConfigured, object: nil)
        
        return true
    }
    
    func getAPIKey() -> String? {
        return keychainManager.retrieve(for: .gemini)
    }
    
    func removeAPIKey() throws {
        try keychainManager.delete(for: .gemini)
        
        Task { @MainActor in
            self.isConfigured = false
            self.lastValidationDate = nil
            self.validationStatus = .unknown
        }
        
        NotificationCenter.default.post(name: .apiKeyRemoved, object: nil)
    }
    
    func rotateAPIKey(_ newKey: String) async throws {
        try await configureAPIKey(newKey)
        
        NotificationCenter.default.post(name: .apiKeyRotated, object: nil)
    }
    
    // MARK: - Validation
    
    func validateCurrentKey() async -> ValidationStatus {
        guard let apiKey = getAPIKey() else {
            await MainActor.run {
                self.validationStatus = .invalid
            }
            return .invalid
        }
        
        let status = await validator.validateKeyDetailed(apiKey)
        
        await MainActor.run {
            self.validationStatus = status
            self.lastValidationDate = Date()
        }
        
        return status
    }
    
    func checkConfiguration() {
        let hasKey = getAPIKey() != nil
        
        Task { @MainActor in
            self.isConfigured = hasKey
            
            if hasKey {
                // Validate in background
                Task {
                    await self.validateCurrentKey()
                }
            }
        }
    }
    
    private func validateKeyFormat(_ key: String) -> Bool {
        // Gemini API keys typically start with "AIza" and are 39 characters long
        let pattern = "^AIza[0-9A-Za-z_-]{35}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: key.utf16.count)
        return regex?.firstMatch(in: key, options: [], range: range) != nil
    }
    
    // MARK: - Setup Interface
    
    func createSetupConfiguration() -> APISetupConfiguration {
        return APISetupConfiguration(
            title: "Gemini API Configuration",
            description: "Enter your Google Gemini API key to enable translation services",
            instructions: [
                "1. Visit Google AI Studio (https://makersuite.google.com/app/apikey)",
                "2. Create a new API key",
                "3. Copy the key and paste it below",
                "4. The key will be stored securely in your device's keychain"
            ],
            placeholder: "AIzaSy...",
            validation: APIKeyValidation(
                minLength: 39,
                maxLength: 39,
                pattern: "^AIza[0-9A-Za-z_-]{35}$",
                testEndpoint: "generateContent"
            )
        )
    }
    
    func getConfigurationStatus() -> APIConfigurationStatus {
        return APIConfigurationStatus(
            isConfigured: isConfigured,
            lastValidated: lastValidationDate,
            status: validationStatus,
            needsSetup: !isConfigured,
            canRotate: isConfigured && validationStatus == .valid
        )
    }
}

// MARK: - Supporting Types

struct APISetupConfiguration {
    let title: String
    let description: String
    let instructions: [String]
    let placeholder: String
    let validation: APIKeyValidation
}

struct APIKeyValidation {
    let minLength: Int
    let maxLength: Int
    let pattern: String
    let testEndpoint: String
}

struct APIConfigurationStatus {
    let isConfigured: Bool
    let lastValidated: Date?
    let status: APIKeyManager.ValidationStatus
    let needsSetup: Bool
    let canRotate: Bool
}

enum APIKeyError: LocalizedError {
    case emptyKey
    case invalidFormat
    case authenticationFailed
    case networkError
    case storageError
    case validationTimeout
    
    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return "API key cannot be empty"
        case .invalidFormat:
            return "Invalid API key format"
        case .authenticationFailed:
            return "API key authentication failed"
        case .networkError:
            return "Network error during validation"
        case .storageError:
            return "Failed to store API key securely"
        case .validationTimeout:
            return "API key validation timed out"
        }
    }
}

class APIKeyValidator {
    private let session: URLSession
    
    init() {
        self.session = NetworkSecurityManager.shared.configureSession()
    }
    
    func validateKey(_ apiKey: String) async throws -> Bool {
        let status = await validateKeyDetailed(apiKey)
        return status == .valid
    }
    
    func validateKeyDetailed(_ apiKey: String) async -> APIKeyManager.ValidationStatus {
        // Test with a simple generateContent request
        let testRequest = createTestRequest(apiKey: apiKey)
        
        do {
            let (_, response) = try await session.data(for: testRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .networkError
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                return .valid
            case 401, 403:
                return .invalid
            case 429:
                return .rateLimited
            case 500...599:
                return .networkError
            default:
                return .invalid
            }
            
        } catch {
            if error.localizedDescription.contains("timeout") {
                return .networkError
            }
            return .invalid
        }
    }
    
    private func createTestRequest(apiKey: String) -> URLRequest {
        guard let url = URL(string: "\(GeminiAPIConfig.baseURL)/\(GeminiAPIConfig.apiVersion)/models/\(GeminiAPIConfig.model):generateContent") else {
            print("❌ [APIKeyManager] Invalid URL for Gemini API validation: \(GeminiAPIConfig.baseURL)/\(GeminiAPIConfig.apiVersion)/models/\(GeminiAPIConfig.model):generateContent")
            // Return a URLRequest with a guaranteed valid URL that will fail validation appropriately
            let fallbackURL = URL(string: "https://invalid-url") ?? URL(fileURLWithPath: "/dev/null")
            return URLRequest(url: fallbackURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.timeoutInterval = 10.0
        
        // Minimal test payload
        let testPayload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Hello"]
                    ]
                ]
            ],
            "generationConfig": [
                "maxOutputTokens": 10
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testPayload)
        } catch {
            print("Failed to create test payload: \(error)")
        }
        
        return request
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let apiKeyConfigured = Notification.Name("apiKeyConfigured")
    static let apiKeyRemoved = Notification.Name("apiKeyRemoved")
    static let apiKeyValidationFailed = Notification.Name("apiKeyValidationFailed")
}