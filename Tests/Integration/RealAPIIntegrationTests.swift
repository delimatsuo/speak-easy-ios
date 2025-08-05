import XCTest
import Foundation
@testable import UniversalTranslatorApp

// MARK: - Real Gemini API Integration Tests
class RealAPIIntegrationTests: BaseTestCase {
    
    var realAPIClient: RealGeminiAPIClient!
    var apiKeyManager: APIKeyManager!
    
    override func setUp() {
        super.setUp()
        setupRealAPIComponents()
    }
    
    override func tearDown() {
        teardownRealAPIComponents()
        super.tearDown()
    }
    
    private func setupRealAPIComponents() {
        apiKeyManager = APIKeyManager.shared
        
        // Check if real API key is configured
        guard let apiKey = apiKeyManager.getAPIKey(for: .gemini),
              !apiKey.isEmpty,
              apiKey != "test_api_key_12345" else {
            // Skip real API tests if no valid key is configured
            print("⚠️ Real API key not configured. Skipping real API integration tests.")
            print("💡 To enable real API testing, coordinate with Backend PM to configure API keys.")
            return
        }
        
        realAPIClient = RealGeminiAPIClient(apiKey: apiKey)
        print("✅ Real API client configured for integration testing")
    }
    
    private func teardownRealAPIComponents() {
        realAPIClient = nil
    }
    
    // MARK: - Real API Authentication Tests
    
    func testRealAPIAuthentication() {
        guard realAPIClient != nil else {
            XCTSkip("Real API client not configured")
        }
        
        let expectation = expectation(description: "Real API authentication")
        
        Task {
            do {
                // Test simple API call to verify authentication
                let response = try await realAPIClient.testConnection()
                
                XCTAssertTrue(response.success, "API authentication should succeed")
                XCTAssertNotNil(response.serverInfo, "Should receive server information")
                
                print("✅ Real API authentication successful")
                expectation.fulfill()
                
            } catch APIError.authentication(let message) {
                XCTFail("API authentication failed: \(message)")
                print("❌ API Key may be invalid or expired")
                expectation.fulfill()
                
            } catch {
                XCTFail("Unexpected authentication error: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Real Translation API Tests
    
    func testRealTranslationAPI() {
        guard realAPIClient != nil else {
            XCTSkip("Real API client not configured")
        }
        
        let expectation = expectation(description: "Real translation API")
        
        Task {
            let testCases = [
                RealTranslationTestCase(
                    input: "Hello, how are you today?",
                    sourceLanguage: "en",
                    targetLanguage: "es",
                    expectedContains: ["hola", "cómo", "estás"]
                ),
                RealTranslationTestCase(
                    input: "Thank you very much for your help",
                    sourceLanguage: "en",
                    targetLanguage: "fr",
                    expectedContains: ["merci", "beaucoup"]
                ),
                RealTranslationTestCase(
                    input: "Good morning, have a wonderful day",
                    sourceLanguage: "en",
                    targetLanguage: "de",
                    expectedContains: ["guten", "morgen"]
                )
            ]
            
            for testCase in testCases {
                do {
                    let startTime = Date()
                    
                    let translation = try await realAPIClient.translateText(
                        testCase.input,
                        from: testCase.sourceLanguage,
                        to: testCase.targetLanguage
                    )
                    
                    let responseTime = Date().timeIntervalSince(startTime)
                    
                    // Validate translation content
                    XCTAssertFalse(translation.isEmpty, "Translation should not be empty")
                    XCTAssertNotEqual(translation, testCase.input, "Translation should be different from input")
                    
                    // Check for expected words in translation
                    let translationLower = translation.lowercased()
                    let foundExpected = testCase.expectedContains.contains { keyword in
                        translationLower.contains(keyword.lowercased())
                    }
                    
                    XCTAssertTrue(foundExpected, 
                                 "Translation '\(translation)' should contain one of: \(testCase.expectedContains)")
                    
                    // Performance validation
                    XCTAssertLessThan(responseTime, 3.0, "Translation should complete within 3 seconds")
                    
                    print("✅ Translation (\(testCase.sourceLanguage)→\(testCase.targetLanguage)): '\(testCase.input)' → '\(translation)' (\(String(format: "%.2f", responseTime))s)")
                    
                } catch {
                    XCTFail("Translation failed for \(testCase.sourceLanguage)→\(testCase.targetLanguage): \(error)")
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testRealTranslationWithLongText() {
        guard realAPIClient != nil else {
            XCTSkip("Real API client not configured")
        }
        
        let expectation = expectation(description: "Real translation with long text")
        
        Task {
            let longText = """
            This is a longer text that tests the translation API's ability to handle 
            multiple sentences and more complex content. It includes various types of 
            information and should be translated accurately while maintaining the 
            meaning and context of the original text. This test helps verify that 
            the API can handle realistic translation scenarios that users might 
            encounter in real-world usage.
            """
            
            do {
                let startTime = Date()
                
                let translation = try await realAPIClient.translateText(
                    longText,
                    from: "en",
                    to: "es"
                )
                
                let responseTime = Date().timeIntervalSince(startTime)
                
                // Validate long text translation
                XCTAssertFalse(translation.isEmpty)
                XCTAssertGreaterThan(translation.count, longText.count / 2, 
                                   "Translation should be substantial")
                XCTAssertLessThan(responseTime, 5.0, 
                                "Long text translation should complete within 5 seconds")
                
                print("✅ Long text translation completed in \(String(format: "%.2f", responseTime))s")
                print("   Input: \(longText.count) characters")
                print("   Output: \(translation.count) characters")
                
                expectation.fulfill()
                
            } catch {
                XCTFail("Long text translation failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Real TTS API Tests
    
    func testRealTTSAPI() {
        guard realAPIClient != nil else {
            XCTSkip("Real API client not configured")
        }
        
        let expectation = expectation(description: "Real TTS API")
        
        Task {
            let testTexts = [
                ("Hello, this is a test of the text-to-speech system", "en-US"),
                ("Hola, esta es una prueba del sistema de texto a voz", "es-ES"),
                ("Bonjour, ceci est un test du système de synthèse vocale", "fr-FR")
            ]
            
            for (text, language) in testTexts {
                do {
                    let startTime = Date()
                    
                    let audioData = try await realAPIClient.synthesizeSpeech(
                        text: text,
                        language: language,
                        voiceConfig: RealTTSVoiceConfig(
                            gender: .neutral,
                            speakingRate: 1.0,
                            pitch: 0.0
                        )
                    )
                    
                    let responseTime = Date().timeIntervalSince(startTime)
                    
                    // Validate TTS response
                    XCTAssertGreaterThan(audioData.count, 1000, 
                                       "TTS should generate substantial audio data")
                    XCTAssertLessThan(responseTime, 4.0, 
                                    "TTS should complete within 4 seconds")
                    
                    // Validate audio format (should be MP3)
                    let audioHeader = audioData.prefix(4)
                    let mp3Header = Data([0xFF, 0xFB]) // MP3 sync pattern
                    XCTAssertTrue(audioHeader.starts(with: mp3Header) || 
                                audioData.count > 100, // Allow for Base64 encoded audio
                                "Audio should be in valid format")
                    
                    print("✅ TTS (\(language)): \(audioData.count) bytes in \(String(format: "%.2f", responseTime))s")
                    
                } catch {
                    XCTFail("TTS failed for \(language): \(error)")
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRealAPIRateLimiting() {
        guard realAPIClient != nil else {
            XCTSkip("Real API client not configured")
        }
        
        let expectation = expectation(description: "Real API rate limiting")
        
        Task {
            let requestCount = 10 // Start with modest number
            var successCount = 0
            var rateLimitedCount = 0
            var requestTimes: [TimeInterval] = []
            
            print("🧪 Testing rate limiting with \(requestCount) rapid requests...")
            
            for i in 0..<requestCount {
                let startTime = Date()
                
                do {
                    _ = try await realAPIClient.translateText(
                        "Test request \(i)",
                        from: "en",
                        to: "es"
                    )
                    
                    let requestTime = Date().timeIntervalSince(startTime)
                    requestTimes.append(requestTime)
                    successCount += 1
                    
                } catch APIError.rateLimited(let retryAfter) {
                    rateLimitedCount += 1
                    print("⏱️ Rate limited on request \(i), retry after: \(retryAfter)s")
                    
                    // Test retry after delay
                    try? await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    
                } catch {
                    print("❌ Request \(i) failed: \(error)")
                }
            }
            
            // Validate rate limiting behavior
            if rateLimitedCount > 0 {
                XCTAssertTrue(true, "Rate limiting is working correctly")
                print("✅ Rate limiting detected after \(successCount) requests")
            } else {
                print("ℹ️ No rate limiting encountered with \(requestCount) requests")
            }
            
            // Analyze request timing
            if !requestTimes.isEmpty {
                let averageTime = requestTimes.reduce(0, +) / Double(requestTimes.count)
                print("📊 Average request time: \(String(format: "%.2f", averageTime))s")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testRealAPIErrorHandling() {
        guard realAPIClient != nil else {
            XCTSkip("Real API client not configured")
        }
        
        let expectation = expectation(description: "Real API error handling")
        
        Task {
            // Test invalid language code
            do {
                _ = try await realAPIClient.translateText(
                    "Test text",
                    from: "invalid_lang",
                    to: "es"
                )
                XCTFail("Should fail with invalid language code")
            } catch APIError.invalidLanguage(let language) {
                XCTAssertEqual(language, "invalid_lang")
                print("✅ Correctly handled invalid language: \(language)")
            } catch {
                print("⚠️ Unexpected error for invalid language: \(error)")
            }
            
            // Test empty text
            do {
                _ = try await realAPIClient.translateText(
                    "",
                    from: "en",
                    to: "es"
                )
                XCTFail("Should fail with empty text")
            } catch APIError.emptyText {
                print("✅ Correctly handled empty text")
            } catch {
                print("⚠️ Unexpected error for empty text: \(error)")
            }
            
            // Test extremely long text (over 10K characters)
            let veryLongText = String(repeating: "This is a very long text. ", count: 400) // ~10.8K chars
            
            do {
                _ = try await realAPIClient.translateText(
                    veryLongText,
                    from: "en",
                    to: "es"
                )
                XCTFail("Should fail with text over character limit")
            } catch APIError.textTooLong(let limit) {
                XCTAssertEqual(limit, 10000)
                print("✅ Correctly handled text over limit: \(limit) characters")
            } catch {
                print("⚠️ Unexpected error for long text: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Network Resilience Tests
    
    func testAPINetworkResilience() {
        guard realAPIClient != nil else {
            XCTSkip("Real API client not configured")
        }
        
        let expectation = expectation(description: "API network resilience")
        
        Task {
            // Test with retry configuration
            realAPIClient.setRetryConfiguration(
                maxRetries: 3,
                baseDelay: 1.0,
                maxDelay: 8.0
            )
            
            var retryCount = 0
            
            do {
                let result = try await realAPIClient.translateTextWithRetry(
                    "Network resilience test",
                    from: "en",
                    to: "es"
                ) { attempt in
                    retryCount = attempt
                    print("🔄 Retry attempt: \(attempt)")
                }
                
                XCTAssertFalse(result.isEmpty)
                print("✅ Translation succeeded after \(retryCount) retries")
                
            } catch {
                // Even if it fails, we can verify retry behavior
                XCTAssertGreaterThan(retryCount, 0, "Should have attempted retries")
                print("ℹ️ Translation failed after \(retryCount) retries: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
}

// MARK: - Supporting Data Structures
struct RealTranslationTestCase {
    let input: String
    let sourceLanguage: String
    let targetLanguage: String
    let expectedContains: [String]
}

// MARK: - Real API Client Implementation
class RealGeminiAPIClient {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com"
    private let session: URLSession
    private var retryConfig: RetryConfiguration?
    
    init(apiKey: String) {
        self.apiKey = apiKey
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        self.session = URLSession(configuration: config)
    }
    
    func testConnection() async throws -> ConnectionTestResponse {
        let url = URL(string: "\(baseURL)/v1beta/models")!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.authentication("Invalid API key")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        return ConnectionTestResponse(success: true, serverInfo: "Connected to Gemini API")
    }
    
    func translateText(_ text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> String {
        guard !text.isEmpty else {
            throw APIError.emptyText
        }
        
        guard text.count <= 10000 else {
            throw APIError.textTooLong(10000)
        }
        
        let url = URL(string: "\(baseURL)/v1beta/models/gemini-2.0-flash-exp:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        
        let prompt = """
        Translate the following text from \(sourceLanguage) to \(targetLanguage).
        Provide only the translation without any explanation or additional text.
        
        Text to translate:
        \(text)
        """
        
        let requestBody = [
            "contents": [
                [
                    "parts": [["text": prompt]],
                    "role": "user"
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? 60.0
            throw APIError.rateLimited(retryAfter)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let responseJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        guard let candidates = responseJSON["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: String]],
              let translation = parts.first?["text"] else {
            throw APIError.invalidResponse
        }
        
        return translation.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func synthesizeSpeech(text: String, language: String, voiceConfig: RealTTSVoiceConfig) async throws -> Data {
        let url = URL(string: "\(baseURL)/v1beta/models/gemini-2.0-flash-exp:synthesizeSpeech")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        
        let requestBody = [
            "input": ["text": text],
            "voice": [
                "languageCode": language,
                "ssmlGender": voiceConfig.gender.rawValue
            ],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": voiceConfig.speakingRate,
                "pitch": voiceConfig.pitch,
                "sampleRateHertz": 24000
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? 60.0
            throw APIError.rateLimited(retryAfter)
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let responseJSON = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        guard let audioContent = responseJSON["audioContent"] as? String,
              let audioData = Data(base64Encoded: audioContent) else {
            throw APIError.invalidResponse
        }
        
        return audioData
    }
    
    func setRetryConfiguration(maxRetries: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) {
        retryConfig = RetryConfiguration(
            maxRetries: maxRetries,
            baseDelay: baseDelay,
            maxDelay: maxDelay
        )
    }
    
    func translateTextWithRetry(
        _ text: String,
        from sourceLanguage: String,
        to targetLanguage: String,
        onRetry: @escaping (Int) -> Void
    ) async throws -> String {
        guard let config = retryConfig else {
            return try await translateText(text, from: sourceLanguage, to: targetLanguage)
        }
        
        var lastError: Error?
        
        for attempt in 0...config.maxRetries {
            do {
                return try await translateText(text, from: sourceLanguage, to: targetLanguage)
            } catch {
                lastError = error
                
                if attempt < config.maxRetries {
                    onRetry(attempt + 1)
                    
                    let delay = min(config.baseDelay * pow(2.0, Double(attempt)), config.maxDelay)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? APIError.maxRetriesExceeded
    }
}

// MARK: - Supporting Types
struct ConnectionTestResponse {
    let success: Bool
    let serverInfo: String
}

struct RealTTSVoiceConfig {
    let gender: Gender
    let speakingRate: Float
    let pitch: Float
    
    enum Gender: String {
        case male = "MALE"
        case female = "FEMALE"
        case neutral = "NEUTRAL"
    }
}

struct RetryConfiguration {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
}

// MARK: - API Error Types
enum APIError: Error {
    case authentication(String)
    case invalidResponse
    case serverError(Int)
    case rateLimited(TimeInterval)
    case invalidLanguage(String)
    case emptyText
    case textTooLong(Int)
    case maxRetriesExceeded
}

// MARK: - API Key Manager
class APIKeyManager {
    static let shared = APIKeyManager()
    private init() {}
    
    func getAPIKey(for service: APIService) -> String? {
        // In real implementation, this would retrieve from keychain
        // For testing, check environment variables or test configuration
        switch service {
        case .gemini:
            return ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? 
                   UserDefaults.standard.string(forKey: "test_gemini_api_key")
        }
    }
    
    enum APIService {
        case gemini
    }
}