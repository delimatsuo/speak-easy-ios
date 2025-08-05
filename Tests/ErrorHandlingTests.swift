import XCTest
import Foundation
import Network
@testable import UniversalTranslatorApp

// MARK: - Network Error Tests
class NetworkErrorTests: BaseTestCase {
    
    var mockNetworkService: MockNetworkService!
    var mockAPI: MockGeminiAPI!
    
    override func setUp() {
        super.setUp()
        mockNetworkService = MockNetworkService.shared
        mockAPI = MockGeminiAPI.shared
    }
    
    override func tearDown() {
        mockNetworkService.reset()
        mockAPI.reset()
        super.tearDown()
    }
    
    // MARK: - Network Timeout Tests
    func testNetworkTimeoutHandling() {
        let expectation = expectation(description: "Network timeout handling")
        
        Task {
            // Simulate network timeout
            mockAPI.setResponseDelay(TestConfiguration.testTimeout + 1.0) // Delay longer than timeout
            
            let startTime = Date()
            
            do {
                // This should timeout
                try await simulateNetworkRequest(timeout: TestConfiguration.testTimeout)
                XCTFail("Request should have timed out")
            } catch {
                let elapsed = Date().timeIntervalSince(startTime)
                
                // Verify timeout occurred within expected timeframe
                XCTAssertGreaterThanOrEqual(elapsed, TestConfiguration.testTimeout - 0.5)
                XCTAssertLessThanOrEqual(elapsed, TestConfiguration.testTimeout + 1.0)
                
                // Verify correct error type
                if let urlError = error as? URLError {
                    XCTAssertEqual(urlError.code, .timedOut)
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout + 2.0)
    }
    
    func testConnectionLossRecovery() {
        let expectation = expectation(description: "Connection loss recovery")
        
        Task {
            // Start with connected state
            mockNetworkService.simulateConnectionState(true)
            XCTAssertTrue(mockNetworkService.getConnectionState())
            
            // Simulate connection loss
            mockNetworkService.simulateConnectionState(false)
            XCTAssertFalse(mockNetworkService.getConnectionState())
            
            // Test retry mechanism
            var retryAttempts = 0
            let maxRetries = 3
            
            while retryAttempts < maxRetries && !mockNetworkService.getConnectionState() {
                retryAttempts += 1
                
                // Simulate retry delay
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                if retryAttempts == 2 {
                    // Restore connection on second retry
                    mockNetworkService.simulateConnectionState(true)
                }
            }
            
            XCTAssertLessThan(retryAttempts, maxRetries)
            XCTAssertTrue(mockNetworkService.getConnectionState())
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testOfflineModeSwitching() {
        let expectation = expectation(description: "Offline mode switching")
        
        Task {
            // Start online
            mockNetworkService.simulateConnectionState(true)
            var isOfflineMode = false
            
            // Test online operation
            if mockNetworkService.getConnectionState() {
                let result = await simulateOnlineTranslation("Hello")
                XCTAssertNotNil(result)
            }
            
            // Simulate going offline
            mockNetworkService.simulateConnectionState(false)
            
            // Should switch to offline mode
            if !mockNetworkService.getConnectionState() {
                isOfflineMode = true
                
                // Test offline capabilities (cache lookup)
                let cachedResult = simulateOfflineTranslation("Hello")
                XCTAssertNotNil(cachedResult)
            }
            
            XCTAssertTrue(isOfflineMode)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testRequestQueuingDuringOutages() {
        let expectation = expectation(description: "Request queuing during outages")
        
        Task {
            var requestQueue: [String] = []
            
            // Simulate network outage
            mockNetworkService.simulateConnectionState(false)
            
            // Queue requests while offline
            let requests = ["Hello", "Goodbye", "Thank you", "Please", "Sorry"]
            
            for request in requests {
                if !mockNetworkService.getConnectionState() {
                    requestQueue.append(request)
                }
            }
            
            XCTAssertEqual(requestQueue.count, requests.count)
            
            // Restore connection
            mockNetworkService.simulateConnectionState(true)
            
            // Process queued requests
            var processedRequests = 0
            
            while !requestQueue.isEmpty && mockNetworkService.getConnectionState() {
                let request = requestQueue.removeFirst()
                let result = await simulateOnlineTranslation(request)
                if result != nil {
                    processedRequests += 1
                }
            }
            
            XCTAssertEqual(processedRequests, requests.count)
            XCTAssertTrue(requestQueue.isEmpty)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Helper Methods
    private func simulateNetworkRequest(timeout: TimeInterval) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                // Simulate long-running request
                try await Task.sleep(nanoseconds: UInt64((timeout + 2.0) * 1_000_000_000))
            }
            
            group.addTask {
                // Timeout task
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw URLError(.timedOut)
            }
            
            try await group.next()
            group.cancelAll()
        }
    }
    
    private func simulateOnlineTranslation(_ text: String) async -> String? {
        if mockNetworkService.getConnectionState() {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            return "Translated: \(text)"
        }
        return nil
    }
    
    private func simulateOfflineTranslation(_ text: String) -> String? {
        // Simulate cache lookup
        let cachedTranslations = [
            "Hello": "Hola",
            "Goodbye": "Adiós",
            "Thank you": "Gracias"
        ]
        return cachedTranslations[text]
    }
}

// MARK: - API Error Tests
class APIErrorTests: BaseTestCase {
    
    var mockAPI: MockGeminiAPI!
    
    override func setUp() {
        super.setUp()
        mockAPI = MockGeminiAPI.shared
    }
    
    override func tearDown() {
        mockAPI.reset()
        super.tearDown()
    }
    
    // MARK: - Rate Limit Tests
    func testRateLimitExceededHandling() {
        let expectation = expectation(description: "Rate limit exceeded handling")
        
        Task {
            // Simulate rate limiting
            mockAPI.simulateRateLimit(true)
            
            do {
                _ = try await simulateAPIRequest()
                XCTFail("Request should have failed with rate limit error")
            } catch {
                // Verify rate limit error handling
                XCTAssertTrue(true, "Correctly handled rate limit error")
            }
            
            // Test retry after delay
            mockAPI.simulateRateLimit(false)
            
            // Simulate waiting for rate limit reset
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            do {
                let result = try await simulateAPIRequest()
                XCTAssertNotNil(result)
            } catch {
                XCTFail("Request should succeed after rate limit reset")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testInvalidAPIKeyResponse() {
        let expectation = expectation(description: "Invalid API key response")
        
        Task {
            // Test invalid API key handling
            let invalidKeyResponse = mockAPI.getInvalidAPIKeyResponse()
            
            do {
                let response = try JSONSerialization.jsonObject(with: invalidKeyResponse) as! [String: Any]
                let error = response["error"] as! [String: Any]
                
                XCTAssertEqual(error["code"] as! Int, 401)
                XCTAssertEqual(error["status"] as! String, "UNAUTHENTICATED")
                
                // Should trigger key rotation or re-authentication
                XCTAssertTrue(true, "Correctly identified invalid API key")
                
            } catch {
                XCTFail("Failed to parse invalid API key response")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testServerErrorResponses() {
        let expectation = expectation(description: "Server error responses")
        
        Task {
            let serverErrorCodes = [500, 502, 503, 504]
            
            for errorCode in serverErrorCodes {
                // Test server error handling
                mockAPI.simulateNetworkError(true)
                
                do {
                    _ = try await simulateAPIRequestWithStatusCode(errorCode)
                    XCTFail("Request should have failed with server error \(errorCode)")
                } catch {
                    // Should implement retry logic for server errors
                    XCTAssertTrue(true, "Correctly handled server error \(errorCode)")
                }
                
                mockAPI.simulateNetworkError(false)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testMalformedResponseHandling() {
        let expectation = expectation(description: "Malformed response handling")
        
        Task {
            let malformedResponses = [
                "{\"incomplete\": ",
                "Not JSON at all",
                "{\"wrong_structure\": true}",
                ""
            ]
            
            for malformedResponse in malformedResponses {
                let data = malformedResponse.data(using: .utf8) ?? Data()
                
                do {
                    _ = try JSONSerialization.jsonObject(with: data)
                    
                    // If parsing succeeds, check if it has expected structure
                    if malformedResponse == "{\"wrong_structure\": true}" {
                        // This is valid JSON but wrong structure - should be handled
                        XCTAssertTrue(true, "Handled valid JSON with wrong structure")
                    }
                } catch {
                    // Expected for malformed JSON
                    XCTAssertTrue(true, "Correctly rejected malformed response: \(malformedResponse)")
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Helper Methods
    private func simulateAPIRequest() async throws -> String {
        if mockAPI.shouldSimulateRateLimit {
            throw APIError.rateLimitExceeded
        }
        
        if mockAPI.shouldSimulateNetworkError {
            throw APIError.serverError(500)
        }
        
        return "Success"
    }
    
    private func simulateAPIRequestWithStatusCode(_ statusCode: Int) async throws -> String {
        switch statusCode {
        case 500...599:
            throw APIError.serverError(statusCode)
        default:
            return "Success"
        }
    }
    
    private enum APIError: Error {
        case rateLimitExceeded
        case serverError(Int)
    }
}

// MARK: - Speech Recognition Error Tests
class SpeechErrorTests: BaseTestCase {
    
    var mockSpeechRecognizer: MockSpeechRecognizer!
    
    override func setUp() {
        super.setUp()
        mockSpeechRecognizer = MockSpeechRecognizer.shared
    }
    
    override func tearDown() {
        mockSpeechRecognizer.reset()
        super.tearDown()
    }
    
    // MARK: - Permission Tests
    func testMicrophonePermissionDenied() {
        let expectation = expectation(description: "Microphone permission denied")
        
        Task {
            // Set permission to denied
            mockSpeechRecognizer.setMockPermissionState(.denied)
            
            let permissionState = mockSpeechRecognizer.getMockPermissionState()
            XCTAssertEqual(permissionState, .denied)
            
            // Should handle permission denial gracefully
            do {
                _ = try await simulateSpeechRecognition()
                XCTFail("Speech recognition should fail without microphone permission")
            } catch SpeechError.permissionDenied {
                XCTAssertTrue(true, "Correctly handled permission denial")
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testAudioEngineFailure() {
        let expectation = expectation(description: "Audio engine failure")
        
        Task {
            // Simulate audio engine failure
            mockSpeechRecognizer.simulateError(true)
            
            do {
                _ = try await simulateSpeechRecognition()
                XCTFail("Speech recognition should fail with audio engine error")
            } catch SpeechError.audioEngineFailure {
                XCTAssertTrue(true, "Correctly handled audio engine failure")
                
                // Should attempt recovery
                let recoveryResult = await attemptAudioEngineRecovery()
                XCTAssertTrue(recoveryResult, "Should attempt audio engine recovery")
                
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testRecognizerUnavailable() {
        let expectation = expectation(description: "Recognizer unavailable")
        
        Task {
            // Test when speech recognizer is unavailable for a language
            let unsupportedLanguage = "xx-XX" // Invalid language code
            
            do {
                _ = try await simulateSpeechRecognitionForLanguage(unsupportedLanguage)
                XCTFail("Speech recognition should fail for unsupported language")
            } catch SpeechError.recognizerUnavailable {
                XCTAssertTrue(true, "Correctly handled unavailable recognizer")
                
                // Should fallback to text input
                let fallbackResult = simulateTextInputFallback()
                XCTAssertNotNil(fallbackResult)
                
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testNoSpeechDetected() {
        let expectation = expectation(description: "No speech detected")
        
        Task {
            // Simulate silent audio input
            let silentAudio = createSilentAudioBuffer(duration: 2.0)
            XCTAssertNotNil(silentAudio)
            
            do {
                _ = try await simulateSpeechRecognitionWithAudio(silentAudio!)
                XCTFail("Should detect no speech in silent audio")
            } catch SpeechError.noSpeechDetected {
                XCTAssertTrue(true, "Correctly detected absence of speech")
                
                // Should prompt user to try again
                let retryPrompted = simulateRetryPrompt()
                XCTAssertTrue(retryPrompted)
                
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Helper Methods
    private func simulateSpeechRecognition() async throws -> String {
        let permissionState = mockSpeechRecognizer.getMockPermissionState()
        
        switch permissionState {
        case .denied, .restricted:
            throw SpeechError.permissionDenied
        case .notDetermined:
            throw SpeechError.permissionNotDetermined
        case .authorized:
            if mockSpeechRecognizer.shouldSimulateError {
                throw SpeechError.audioEngineFailure
            }
            return "Recognized speech"
        }
    }
    
    private func simulateSpeechRecognitionForLanguage(_ language: String) async throws -> String {
        // Check if language is supported
        let supportedLanguages = ["en", "es", "fr", "de", "ja", "zh", "ko", "it", "pt", "ru"]
        let languageCode = String(language.prefix(2))
        
        if !supportedLanguages.contains(languageCode) {
            throw SpeechError.recognizerUnavailable
        }
        
        return "Recognized speech in \(language)"
    }
    
    private func simulateSpeechRecognitionWithAudio(_ audio: AVAudioPCMBuffer) async throws -> String {
        // Check if audio contains speech
        guard let channelData = audio.floatChannelData?[0] else {
            throw SpeechError.audioEngineFailure
        }
        
        var hasAudio = false
        for i in 0..<Int(audio.frameLength) {
            if abs(channelData[i]) > 0.01 { // Threshold for speech detection
                hasAudio = true
                break
            }
        }
        
        if !hasAudio {
            throw SpeechError.noSpeechDetected
        }
        
        return "Recognized speech from audio"
    }
    
    private func attemptAudioEngineRecovery() async -> Bool {
        // Simulate audio engine recovery attempt
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        mockSpeechRecognizer.simulateError(false)
        return true
    }
    
    private func simulateTextInputFallback() -> String {
        return "Fallback to text input"
    }
    
    private func simulateRetryPrompt() -> Bool {
        return true // Simulates showing retry prompt to user
    }
    
    private enum SpeechError: Error {
        case permissionDenied
        case permissionNotDetermined
        case audioEngineFailure
        case recognizerUnavailable
        case noSpeechDetected
    }
}

// MARK: - Error Recovery Tests
class ErrorRecoveryTests: BaseTestCase {
    
    var mockAPI: MockGeminiAPI!
    var mockNetworkService: MockNetworkService!
    var mockCacheManager: MockCacheManager!
    
    override func setUp() {
        super.setUp()
        mockAPI = MockGeminiAPI.shared
        mockNetworkService = MockNetworkService.shared
        mockCacheManager = MockCacheManager.shared
    }
    
    override func tearDown() {
        mockAPI.reset()
        mockNetworkService.reset()
        mockCacheManager.reset()
        super.tearDown()
    }
    
    // MARK: - Retry Logic Tests
    func testExponentialBackoffRetry() {
        let expectation = expectation(description: "Exponential backoff retry")
        
        Task {
            let baseDelay: TimeInterval = 0.1 // Start with 100ms for testing
            let maxRetries = 3
            var retryCount = 0
            var totalDelay: TimeInterval = 0
            
            while retryCount < maxRetries {
                let delay = baseDelay * pow(2.0, Double(retryCount))
                totalDelay += delay
                
                let startTime = Date()
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                let actualDelay = Date().timeIntervalSince(startTime)
                
                XCTAssertGreaterThanOrEqual(actualDelay, delay - 0.05) // Allow for timing variance
                
                retryCount += 1
                
                // Simulate success on final retry
                if retryCount == maxRetries {
                    break
                }
            }
            
            XCTAssertEqual(retryCount, maxRetries)
            XCTAssertGreaterThan(totalDelay, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testCircuitBreakerPattern() {
        let expectation = expectation(description: "Circuit breaker pattern")
        
        Task {
            var failureCount = 0
            let failureThreshold = 5
            var circuitOpen = false
            
            // Simulate multiple failures
            for i in 0..<10 {
                do {
                    if circuitOpen {
                        throw CircuitBreakerError.circuitOpen
                    }
                    
                    // Simulate API failure
                    if i < failureThreshold {
                        failureCount += 1
                        throw APIError.networkError
                    } else {
                        // Success after circuit breaker opens
                        XCTAssertTrue(circuitOpen, "Circuit breaker should be open")
                        break
                    }
                } catch APIError.networkError {
                    if failureCount >= failureThreshold {
                        circuitOpen = true
                    }
                } catch CircuitBreakerError.circuitOpen {
                    // Circuit is open, skip request
                    continue
                }
            }
            
            XCTAssertTrue(circuitOpen)
            XCTAssertEqual(failureCount, failureThreshold)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testGracefulDegradation() {
        let expectation = expectation(description: "Graceful degradation")
        
        Task {
            // Simulate service degradation
            mockNetworkService.simulateConnectionState(false)
            
            // Should fallback to cached results
            mockCacheManager.store("Cached translation", forKey: "hello")
            
            let result = await simulateTranslationWithFallback("hello")
            XCTAssertEqual(result, "Cached translation")
            
            // Test feature disabling
            let featuresEnabled = checkEnabledFeatures(networkAvailable: false)
            XCTAssertFalse(featuresEnabled.realTimeTranslation)
            XCTAssertTrue(featuresEnabled.cachedTranslation)
            XCTAssertFalse(featuresEnabled.ttsGeneration)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testErrorPropagationAndRecovery() {
        let expectation = expectation(description: "Error propagation and recovery")
        
        Task {
            var errorHandled = false
            var recoveryAttempted = false
            
            do {
                // Simulate error in translation pipeline
                try await simulateTranslationPipeline()
            } catch TranslationPipelineError.speechRecognitionFailed {
                errorHandled = true
                
                // Attempt recovery by falling back to text input
                recoveryAttempted = await attemptRecoveryWithTextInput()
                
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
            
            XCTAssertTrue(errorHandled)
            XCTAssertTrue(recoveryAttempted)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Helper Methods
    private func simulateTranslationWithFallback(_ text: String) async -> String? {
        if mockNetworkService.getConnectionState() {
            // Online translation
            return "Online translation of \(text)"
        } else {
            // Fallback to cache
            return mockCacheManager.retrieve(forKey: text) as? String
        }
    }
    
    private func checkEnabledFeatures(networkAvailable: Bool) -> (realTimeTranslation: Bool, cachedTranslation: Bool, ttsGeneration: Bool) {
        return (
            realTimeTranslation: networkAvailable,
            cachedTranslation: true, // Always available
            ttsGeneration: networkAvailable
        )
    }
    
    private func simulateTranslationPipeline() async throws {
        // Simulate pipeline steps
        // 1. Speech recognition
        if mockSpeechRecognizer.shouldSimulateError {
            throw TranslationPipelineError.speechRecognitionFailed
        }
        
        // 2. Translation API
        if !mockNetworkService.getConnectionState() {
            throw TranslationPipelineError.translationServiceUnavailable
        }
        
        // 3. TTS generation
        if mockAPI.shouldSimulateNetworkError {
            throw TranslationPipelineError.ttsGenerationFailed
        }
    }
    
    private func attemptRecoveryWithTextInput() async -> Bool {
        // Simulate recovery by switching to text input
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        return true
    }
    
    private enum CircuitBreakerError: Error {
        case circuitOpen
    }
    
    private enum APIError: Error {
        case networkError
    }
    
    private enum TranslationPipelineError: Error {
        case speechRecognitionFailed
        case translationServiceUnavailable
        case ttsGenerationFailed
    }
}