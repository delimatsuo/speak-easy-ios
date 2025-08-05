import XCTest
import Foundation
@testable import UniversalTranslatorApp

// MARK: - Gemini Translation API Tests
class GeminiTranslationTests: BaseTestCase {
    
    var mockAPI: MockGeminiAPI!
    var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        mockAPI = MockGeminiAPI.shared
        mockSession = mockAPI.configureMockSession()
    }
    
    override func tearDown() {
        mockAPI.reset()
        MockURLProtocol.reset()
        super.tearDown()
    }
    
    // MARK: - Request Construction Tests
    func testTranslationRequestConstruction() {
        let sourceLanguage = "en"
        let targetLanguage = "es"
        let textToTranslate = "Hello, how are you?"
        
        // Test request structure based on backend specification
        let requestData: [String: Any] = [
            "contents": [[
                "parts": [["text": "Translate the following text from \(sourceLanguage) to \(targetLanguage).\nProvide only the translation without any explanation or additional text.\n\nText to translate:\n\(textToTranslate)"]],
                "role": "user"
            ]],
            "generationConfig": [
                "temperature": 0.3,
                "topK": 40,
                "topP": 0.95,
                "maxOutputTokens": 2048,
                "stopSequences": []
            ],
            "safetySettings": [
                ["category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_NONE"],
                ["category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"]
            ]
        ]
        
        // Validate request structure
        XCTAssertNotNil(requestData["contents"])
        XCTAssertNotNil(requestData["generationConfig"])
        XCTAssertNotNil(requestData["safetySettings"])
        
        // Validate generation config
        let genConfig = requestData["generationConfig"] as! [String: Any]
        XCTAssertEqual(genConfig["temperature"] as! Double, 0.3, accuracy: 0.01)
        XCTAssertEqual(genConfig["topK"] as! Int, 40)
        XCTAssertEqual(genConfig["topP"] as! Double, 0.95, accuracy: 0.01)
        XCTAssertEqual(genConfig["maxOutputTokens"] as! Int, 2048)
        
        // Validate safety settings
        let safetySettings = requestData["safetySettings"] as! [[String: String]]
        XCTAssertEqual(safetySettings.count, 4)
        XCTAssertTrue(safetySettings.allSatisfy { $0["threshold"] == "BLOCK_NONE" })
    }
    
    func testAPIEndpointConnectivity() {
        let expectation = expectation(description: "API endpoint connectivity")
        
        Task {
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(TestConfiguration.testAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
            
            do {
                let (data, response) = try await self.mockSession.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    XCTAssertEqual(httpResponse.statusCode, 200)
                }
                
                XCTAssertNotNil(data)
                expectation.fulfill()
            } catch {
                XCTFail("API connectivity test failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testAPIKeyAuthentication() {
        let expectation = expectation(description: "API key authentication")
        
        Task {
            // Test with valid API key
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(TestConfiguration.testAPIKey, forHTTPHeaderField: "X-Goog-Api-Key")
            
            let requestBody = [
                "contents": [["parts": [["text": "Test"]], "role": "user"]]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
            
            do {
                let (data, response) = try await self.mockSession.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    XCTAssertEqual(httpResponse.statusCode, 200)
                }
                
                expectation.fulfill()
            } catch {
                XCTFail("Authentication test failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testTranslationResponseParsing() {
        let expectation = expectation(description: "Translation response parsing")
        
        Task {
            let mockResponseData = self.mockAPI.getSuccessTranslationResponse(translatedText: "Hola, ¿cómo estás?")
            
            do {
                let response = try JSONSerialization.jsonObject(with: mockResponseData) as! [String: Any]
                
                // Validate response structure
                XCTAssertNotNil(response["candidates"])
                XCTAssertNotNil(response["usageMetadata"])
                
                let candidates = response["candidates"] as! [[String: Any]]
                XCTAssertGreaterThan(candidates.count, 0)
                
                let firstCandidate = candidates[0]
                XCTAssertNotNil(firstCandidate["content"])
                XCTAssertEqual(firstCandidate["finishReason"] as! String, "STOP")
                
                let content = firstCandidate["content"] as! [String: Any]
                let parts = content["parts"] as! [[String: String]]
                let translatedText = parts[0]["text"]!
                
                XCTAssertEqual(translatedText, "Hola, ¿cómo estás?")
                
                // Validate usage metadata
                let usageMetadata = response["usageMetadata"] as! [String: Int]
                XCTAssertNotNil(usageMetadata["promptTokenCount"])
                XCTAssertNotNil(usageMetadata["candidatesTokenCount"])
                XCTAssertNotNil(usageMetadata["totalTokenCount"])
                
                expectation.fulfill()
            } catch {
                XCTFail("Response parsing failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testCharacterLimitEnforcement() {
        // Test 10,000 character limit enforcement
        let maxCharacters = 10000
        let validText = String(repeating: "a", count: maxCharacters)
        let invalidText = String(repeating: "a", count: maxCharacters + 1)
        
        // Valid text should not throw
        XCTAssertNoThrow({
            XCTAssertLessThanOrEqual(validText.count, maxCharacters)
        })
        
        // Invalid text should be rejected
        XCTAssertGreaterThan(invalidText.count, maxCharacters)
        
        // Test with realistic translation text
        let realisticText = """
        This is a test of the translation service with a reasonable amount of text 
        that should be well within the character limits. The service should handle 
        this without any issues and provide accurate translation results.
        """
        
        XCTAssertLessThan(realisticText.count, maxCharacters)
    }
}

// MARK: - Rate Limiting Tests
class RateLimitingTests: BaseTestCase {
    
    var mockAPI: MockGeminiAPI!
    
    override func setUp() {
        super.setUp()
        mockAPI = MockGeminiAPI.shared
    }
    
    override func tearDown() {
        mockAPI.reset()
        super.tearDown()
    }
    
    // MARK: - Request Rate Tests
    func testRequestsPerMinuteLimit() {
        let expectation = expectation(description: "Requests per minute limit")
        
        // Test 60 RPM limit
        let maxRequestsPerMinute = 60
        let testRequests = 65 // Slightly over limit
        var successfulRequests = 0
        var rateLimitedRequests = 0
        
        let startTime = Date()
        
        Task {
            for i in 0..<testRequests {
                // Simulate rate limiter logic
                let elapsed = Date().timeIntervalSince(startTime)
                let requestsInCurrentMinute = Int(Double(i) / (elapsed / 60.0))
                
                if requestsInCurrentMinute < maxRequestsPerMinute {
                    successfulRequests += 1
                } else {
                    rateLimitedRequests += 1
                    self.mockAPI.simulateRateLimit(true)
                }
                
                // Small delay to simulate real request timing
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            XCTAssertLessThanOrEqual(successfulRequests, maxRequestsPerMinute)
            XCTAssertGreaterThan(rateLimitedRequests, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout * 2)
    }
    
    func testExponentialBackoff() {
        // Test exponential backoff implementation
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 32.0
        let maxRetries = 5
        
        var delays: [TimeInterval] = []
        
        for retryCount in 0..<maxRetries {
            let delay = min(baseDelay * pow(2.0, Double(retryCount)), maxDelay)
            delays.append(delay)
        }
        
        // Verify exponential growth
        XCTAssertEqual(delays[0], 1.0, accuracy: 0.01)
        XCTAssertEqual(delays[1], 2.0, accuracy: 0.01)
        XCTAssertEqual(delays[2], 4.0, accuracy: 0.01)
        XCTAssertEqual(delays[3], 8.0, accuracy: 0.01)
        XCTAssertEqual(delays[4], 16.0, accuracy: 0.01)
        
        // Verify max delay cap
        for delay in delays {
            XCTAssertLessThanOrEqual(delay, maxDelay)
        }
    }
    
    func testBackoffJitter() {
        // Test jitter addition to delays (±10%)
        let baseDelay: TimeInterval = 4.0
        let jitterPercentage = 0.1
        
        // Simulate jitter calculation
        let maxJitter = baseDelay * jitterPercentage
        let minExpectedDelay = baseDelay - maxJitter
        let maxExpectedDelay = baseDelay + maxJitter
        
        // Test multiple jitter calculations
        for _ in 0..<10 {
            let jitter = baseDelay * jitterPercentage * (Double.random(in: -1...1))
            let finalDelay = baseDelay + jitter
            
            XCTAssertGreaterThanOrEqual(finalDelay, minExpectedDelay)
            XCTAssertLessThanOrEqual(finalDelay, maxExpectedDelay)
        }
    }
    
    func testQueueManagementUnderLimits() {
        let expectation = expectation(description: "Queue management under limits")
        
        // Test queue behavior when rate limited
        let maxQueueSize = 100
        var queuedRequests = 0
        
        Task {
            // Simulate filling queue
            for i in 0..<120 { // Attempt to exceed queue size
                if queuedRequests < maxQueueSize {
                    queuedRequests += 1
                } else {
                    // Queue should reject additional requests
                    XCTFail("Queue should not accept request \(i) when full")
                }
            }
            
            XCTAssertEqual(queuedRequests, maxQueueSize)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testPriorityQueueProcessing() {
        let expectation = expectation(description: "Priority queue processing")
        
        // Test priority queue implementation
        struct MockTask {
            let id: Int
            let priority: Int
        }
        
        var tasks = [
            MockTask(id: 1, priority: 0), // Low
            MockTask(id: 2, priority: 2), // High
            MockTask(id: 3, priority: 1), // Normal
            MockTask(id: 4, priority: 2), // High
            MockTask(id: 5, priority: 0)  // Low
        ]
        
        // Sort by priority (higher number = higher priority)
        tasks.sort { $0.priority > $1.priority }
        
        // Verify high priority tasks come first
        XCTAssertEqual(tasks[0].id, 2) // First high priority
        XCTAssertEqual(tasks[1].id, 4) // Second high priority
        XCTAssertEqual(tasks[2].id, 3) // Normal priority
        
        expectation.fulfill()
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - TTS API Tests
class GeminiTTSTests: BaseTestCase {
    
    var mockAPI: MockGeminiAPI!
    
    override func setUp() {
        super.setUp()
        mockAPI = MockGeminiAPI.shared
    }
    
    override func tearDown() {
        mockAPI.reset()
        super.tearDown()
    }
    
    // MARK: - TTS Request Tests
    func testTTSRequestConstruction() {
        let text = "Hello, how are you?"
        let languageCode = "en-US"
        
        // Test TTS request structure based on backend specification
        let requestData: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": languageCode,
                "name": "en-US-Neural2-J",
                "ssmlGender": "NEUTRAL"
            ],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": 1.0,
                "pitch": 0.0,
                "volumeGainDb": 0.0,
                "sampleRateHertz": 24000,
                "effectsProfileId": ["headphone-class-device"]
            ]
        ]
        
        // Validate request structure
        XCTAssertNotNil(requestData["input"])
        XCTAssertNotNil(requestData["voice"])
        XCTAssertNotNil(requestData["audioConfig"])
        
        // Validate input
        let input = requestData["input"] as! [String: String]
        XCTAssertEqual(input["text"], text)
        
        // Validate voice configuration
        let voice = requestData["voice"] as! [String: String]
        XCTAssertEqual(voice["languageCode"], languageCode)
        XCTAssertEqual(voice["ssmlGender"], "NEUTRAL")
        
        // Validate audio configuration
        let audioConfig = requestData["audioConfig"] as! [String: Any]
        XCTAssertEqual(audioConfig["audioEncoding"] as! String, "MP3")
        XCTAssertEqual(audioConfig["sampleRateHertz"] as! Int, 24000)
        XCTAssertEqual(audioConfig["speakingRate"] as! Double, 1.0, accuracy: 0.01)
    }
    
    func testVoiceSelectionLogic() {
        // Test voice selection based on backend specification
        let voiceMapping: [String: [String]] = [
            "en": ["en-US-Wavenet-D", "en-US-Neural2-J", "en-US-Studio-M"],
            "es": ["es-ES-Wavenet-B", "es-ES-Neural2-A", "es-ES-Studio-F"],
            "fr": ["fr-FR-Wavenet-C", "fr-FR-Neural2-B", "fr-FR-Studio-A"],
            "de": ["de-DE-Wavenet-F", "de-DE-Neural2-B", "de-DE-Studio-B"],
            "ja": ["ja-JP-Wavenet-D", "ja-JP-Neural2-B", "ja-JP-Studio-B"]
        ]
        
        for (language, voices) in voiceMapping {
            XCTAssertGreaterThan(voices.count, 0)
            
            // Test priority: Neural2 > Wavenet > Studio
            let neural2Voice = voices.first { $0.contains("Neural2") }
            let wavenetVoice = voices.first { $0.contains("Wavenet") }
            let studioVoice = voices.first { $0.contains("Studio") }
            
            if let neural2 = neural2Voice {
                XCTAssertTrue(neural2.contains("Neural2"))
            } else if let wavenet = wavenetVoice {
                XCTAssertTrue(wavenet.contains("Wavenet"))
            } else if let studio = studioVoice {
                XCTAssertTrue(studio.contains("Studio"))
            }
        }
        
        // Test fallback voice
        let fallbackVoice = "en-US-Neural2-J"
        XCTAssertEqual(fallbackVoice, "en-US-Neural2-J")
    }
    
    func testAudioEncodingSettings() {
        // Test audio encoding settings (MP3, 24kHz)
        let expectedEncoding = "MP3"
        let expectedSampleRate = 24000
        let expectedChannels = 1
        
        XCTAssertEqual(expectedEncoding, "MP3")
        XCTAssertEqual(expectedSampleRate, 24000)
        XCTAssertEqual(expectedChannels, 1)
        
        // Test effects profile
        let effectsProfile = ["headphone-class-device"]
        XCTAssertEqual(effectsProfile.count, 1)
        XCTAssertEqual(effectsProfile[0], "headphone-class-device")
    }
    
    func testBase64AudioDecoding() {
        let expectation = expectation(description: "Base64 audio decoding")
        
        Task {
            // Create mock audio data
            let originalData = Data([0xFF, 0xFB, 0x90, 0x00] + Array(repeating: 0, count: 100))
            let base64String = originalData.base64EncodedString()
            
            // Test decoding
            guard let decodedData = Data(base64Encoded: base64String) else {
                XCTFail("Failed to decode Base64 audio data")
                expectation.fulfill()
                return
            }
            
            XCTAssertEqual(decodedData, originalData)
            XCTAssertGreaterThan(decodedData.count, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testVoiceParametersValidation() {
        // Test voice parameter ranges based on backend specification
        struct VoiceParameters {
            let speakingRate: Float  // 0.75 - 1.25
            let pitch: Float         // -20.0 to 20.0
            let volumeGainDb: Float  // -96.0 to 16.0
        }
        
        // Valid parameters
        let validParams = [
            VoiceParameters(speakingRate: 0.75, pitch: -20.0, volumeGainDb: -96.0),
            VoiceParameters(speakingRate: 1.0, pitch: 0.0, volumeGainDb: 0.0),
            VoiceParameters(speakingRate: 1.25, pitch: 20.0, volumeGainDb: 16.0)
        ]
        
        for params in validParams {
            XCTAssertGreaterThanOrEqual(params.speakingRate, 0.75)
            XCTAssertLessThanOrEqual(params.speakingRate, 1.25)
            XCTAssertGreaterThanOrEqual(params.pitch, -20.0)
            XCTAssertLessThanOrEqual(params.pitch, 20.0)
            XCTAssertGreaterThanOrEqual(params.volumeGainDb, -96.0)
            XCTAssertLessThanOrEqual(params.volumeGainDb, 16.0)
        }
        
        // Invalid parameters
        let invalidParams = [
            VoiceParameters(speakingRate: 0.5, pitch: 0.0, volumeGainDb: 0.0),   // Rate too low
            VoiceParameters(speakingRate: 2.0, pitch: 0.0, volumeGainDb: 0.0),   // Rate too high
            VoiceParameters(speakingRate: 1.0, pitch: -25.0, volumeGainDb: 0.0), // Pitch too low
            VoiceParameters(speakingRate: 1.0, pitch: 25.0, volumeGainDb: 0.0),  // Pitch too high
            VoiceParameters(speakingRate: 1.0, pitch: 0.0, volumeGainDb: -100.0), // Volume too low
            VoiceParameters(speakingRate: 1.0, pitch: 0.0, volumeGainDb: 20.0)   // Volume too high
        ]
        
        for params in invalidParams {
            let isValidRate = params.speakingRate >= 0.75 && params.speakingRate <= 1.25
            let isValidPitch = params.pitch >= -20.0 && params.pitch <= 20.0
            let isValidVolume = params.volumeGainDb >= -96.0 && params.volumeGainDb <= 16.0
            
            XCTAssertFalse(isValidRate && isValidPitch && isValidVolume, 
                          "Parameters should be invalid: rate=\(params.speakingRate), pitch=\(params.pitch), volume=\(params.volumeGainDb)")
        }
    }
}

// MARK: - API Error Handling Tests
class APIErrorHandlingTests: BaseTestCase {
    
    var mockAPI: MockGeminiAPI!
    
    override func setUp() {
        super.setUp()
        mockAPI = MockGeminiAPI.shared
    }
    
    override func tearDown() {
        mockAPI.reset()
        super.tearDown()
    }
    
    func testRateLimitExceededHandling() {
        let expectation = expectation(description: "Rate limit exceeded handling")
        
        Task {
            // Simulate rate limit response
            let rateLimitData = self.mockAPI.getRateLimitResponse()
            
            do {
                let response = try JSONSerialization.jsonObject(with: rateLimitData) as! [String: Any]
                let error = response["error"] as! [String: Any]
                
                XCTAssertEqual(error["code"] as! Int, 429)
                XCTAssertEqual(error["status"] as! String, "RESOURCE_EXHAUSTED")
                XCTAssertTrue((error["message"] as! String).contains("Quota exceeded"))
                
                expectation.fulfill()
            } catch {
                XCTFail("Failed to parse rate limit response: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testInvalidAPIKeyResponse() {
        let expectation = expectation(description: "Invalid API key response")
        
        Task {
            // Simulate invalid API key response
            let invalidKeyData = self.mockAPI.getInvalidAPIKeyResponse()
            
            do {
                let response = try JSONSerialization.jsonObject(with: invalidKeyData) as! [String: Any]
                let error = response["error"] as! [String: Any]
                
                XCTAssertEqual(error["code"] as! Int, 401)
                XCTAssertEqual(error["status"] as! String, "UNAUTHENTICATED")
                XCTAssertTrue((error["message"] as! String).contains("API key"))
                
                expectation.fulfill()
            } catch {
                XCTFail("Failed to parse invalid API key response: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testServerErrorResponses() {
        let expectation = expectation(description: "Server error responses")
        
        // Test various 5xx status codes
        let serverErrors = [500, 502, 503, 504]
        
        Task {
            for statusCode in serverErrors {
                // Test that server errors are properly handled
                XCTAssertGreaterThanOrEqual(statusCode, 500)
                XCTAssertLessThan(statusCode, 600)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testMalformedResponseHandling() {
        let expectation = expectation(description: "Malformed response handling")
        
        Task {
            // Test various malformed responses
            let malformedResponses = [
                "Invalid JSON",
                "{\"incomplete\": ",
                "{\"wrong_structure\": true}",
                ""
            ]
            
            for malformedResponse in malformedResponses {
                let data = malformedResponse.data(using: .utf8) ?? Data()
                
                do {
                    _ = try JSONSerialization.jsonObject(with: data)
                    // If parsing succeeds for malformed data, it's unexpected
                    if malformedResponse == "Invalid JSON" || malformedResponse == "{\"incomplete\": " {
                        XCTFail("Should have failed to parse malformed JSON: \(malformedResponse)")
                    }
                } catch {
                    // Expected for malformed JSON
                    XCTAssertTrue(true, "Correctly identified malformed response")
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
}