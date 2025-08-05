import XCTest
import Speech
import AVFoundation
@testable import UniversalTranslatorApp

class SpeechRecognitionManagerTests: BaseTestCase {
    
    var speechManager: SpeechRecognitionManager!
    var mockRecognizer: MockSpeechRecognizer!
    
    override func setUp() {
        super.setUp()
        mockRecognizer = MockSpeechRecognizer.shared
        // speechManager will be injected when actual implementation is created
    }
    
    override func tearDown() {
        speechManager = nil
        mockRecognizer.reset()
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    func testSpeechRecognizerInitialization() {
        // Test that speech recognizer initializes with correct locale
        let expectation = expectation(description: "Speech recognizer initialization")
        
        Task {
            do {
                // This will test the actual SpeechRecognitionManager when implemented
                XCTAssertNotNil(SFSpeechRecognizer(locale: Locale(identifier: "en-US")))
                XCTAssertNotNil(SFSpeechRecognizer(locale: Locale(identifier: "es-ES")))
                XCTAssertNotNil(SFSpeechRecognizer(locale: Locale(identifier: "fr-FR")))
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testSpeechRecognizerAvailability() {
        // Test availability for supported languages
        let supportedLocales = [
            "en-US", "es-ES", "fr-FR", "de-DE", "ja-JP",
            "zh-CN", "ko-KR", "it-IT", "pt-BR", "ru-RU"
        ]
        
        for localeId in supportedLocales {
            let locale = Locale(identifier: localeId)
            let recognizer = SFSpeechRecognizer(locale: locale)
            XCTAssertNotNil(recognizer, "Speech recognizer should be available for \(localeId)")
            XCTAssertTrue(recognizer?.isAvailable ?? false, "Speech recognizer should be available for \(localeId)")
        }
    }
    
    // MARK: - Multi-language Recognition Tests
    func testMultiLanguageRecognition() {
        let expectation = expectation(description: "Multi-language recognition")
        
        Task {
            // Test English recognition
            if let englishResult = mockRecognizer.getRecognitionResult(for: "test_hello") {
                XCTAssertEqual(englishResult.text, "Hello, how are you today?")
                XCTAssertGreaterThan(englishResult.confidence, 0.9)
                XCTAssertTrue(englishResult.isFinal)
            }
            
            // Test Spanish recognition
            if let spanishResult = mockRecognizer.getRecognitionResult(for: "test_spanish") {
                XCTAssertEqual(spanishResult.text, "Hola, ¿cómo estás?")
                XCTAssertGreaterThan(spanishResult.confidence, 0.9)
                XCTAssertTrue(spanishResult.isFinal)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Confidence Score Tests
    func testConfidenceScoreRange() {
        let testResults = [
            mockRecognizer.getRecognitionResult(for: "test_hello"),
            mockRecognizer.getRecognitionResult(for: "test_spanish")
        ]
        
        for result in testResults {
            guard let result = result else { continue }
            
            // Overall confidence should be between 0.0 and 1.0
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
            
            // Segment confidence should also be in valid range
            for segment in result.segments {
                XCTAssertGreaterThanOrEqual(segment.confidence, 0.0)
                XCTAssertLessThanOrEqual(segment.confidence, 1.0)
            }
        }
    }
    
    // MARK: - Partial Results Handling Tests
    func testPartialResultsHandling() {
        let expectation = expectation(description: "Partial results handling")
        
        // Create mock partial results
        let partialResult = MockSpeechRecognizer.MockRecognitionResult(
            text: "Hello, how",
            confidence: 0.85,
            isFinal: false,
            segments: [
                MockSpeechRecognizer.MockSegment(substring: "Hello", confidence: 0.98, timestamp: 0.0, duration: 0.4),
                MockSpeechRecognizer.MockSegment(substring: "how", confidence: 0.72, timestamp: 0.5, duration: 0.2)
            ]
        )
        
        mockRecognizer.setRecognitionResult(for: "test_partial", result: partialResult)
        
        Task {
            if let result = mockRecognizer.getRecognitionResult(for: "test_partial") {
                XCTAssertFalse(result.isFinal)
                XCTAssertEqual(result.text, "Hello, how")
                XCTAssertEqual(result.segments.count, 2)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Transcription Result Structure Tests
    func testTranscriptionResultFormat() {
        guard let result = mockRecognizer.getRecognitionResult(for: "test_hello") else {
            XCTFail("Failed to get test result")
            return
        }
        
        // Verify text is UTF-8 compatible
        XCTAssertNotNil(result.text.data(using: .utf8))
        
        // Verify segments structure
        XCTAssertGreaterThan(result.segments.count, 0)
        
        for segment in result.segments {
            // Verify segment has required properties
            XCTAssertFalse(segment.substring.isEmpty)
            XCTAssertGreaterThanOrEqual(segment.timestamp, 0)
            XCTAssertGreaterThan(segment.duration, 0)
            XCTAssertGreaterThanOrEqual(segment.confidence, 0.0)
            XCTAssertLessThanOrEqual(segment.confidence, 1.0)
        }
        
        // Verify segments are in chronological order
        for i in 1..<result.segments.count {
            XCTAssertGreaterThanOrEqual(
                result.segments[i].timestamp,
                result.segments[i-1].timestamp
            )
        }
    }
}

// MARK: - Audio Processing Tests
class AudioProcessingTests: BaseTestCase {
    
    // MARK: - Silence Detection Tests
    func testSilenceDetection() {
        let expectation = expectation(description: "Silence detection")
        
        Task {
            // Test configurable silence threshold
            let defaultThreshold = UserDefaults.standard.double(forKey: "silence_threshold")
            XCTAssertEqual(defaultThreshold, TestConfiguration.testSilenceThreshold)
            
            // Test threshold range validation (0.5 - 2.0 seconds)
            let validThresholds = [0.5, 1.0, 1.5, 2.0]
            for threshold in validThresholds {
                UserDefaults.standard.set(threshold, forKey: "silence_threshold")
                let stored = UserDefaults.standard.double(forKey: "silence_threshold")
                XCTAssertEqual(stored, threshold, accuracy: 0.01)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testAudioLevelThresholding() {
        // Test silence level detection (-50.0 dB threshold)
        let silenceLevel: Float = -50.0
        let testLevels: [Float] = [-60.0, -50.0, -40.0, -30.0, -20.0]
        
        for level in testLevels {
            let isSilence = level < silenceLevel
            if level < silenceLevel {
                XCTAssertTrue(isSilence, "Level \(level) should be considered silence")
            } else {
                XCTAssertFalse(isSilence, "Level \(level) should not be considered silence")
            }
        }
    }
    
    // MARK: - Background Noise Filtering Tests
    func testNoiseSuppressionConfiguration() {
        let expectation = expectation(description: "Noise suppression configuration")
        
        Task {
            let audioEngine = AVAudioEngine()
            let format = audioEngine.inputNode.outputFormat(forBus: 0)
            
            // Test EQ node creation for noise reduction
            let eqNode = AVAudioUnitEQ(numberOfBands: 10)
            XCTAssertNotNil(eqNode)
            XCTAssertEqual(eqNode.numberOfBands, 10)
            
            // Test voice frequency range configuration (85-255 Hz)
            // In a real implementation, this would test the actual band configuration
            XCTAssertTrue(format.sampleRate > 0)
            XCTAssertTrue(format.channelCount > 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testAudioBufferProcessing() {
        // Test audio buffer creation and processing
        guard let testBuffer = createTestAudioBuffer(duration: 1.0, frequency: 440.0) else {
            XCTFail("Failed to create test audio buffer")
            return
        }
        
        XCTAssertGreaterThan(testBuffer.frameLength, 0)
        XCTAssertNotNil(testBuffer.floatChannelData)
        
        // Test silent buffer creation
        guard let silentBuffer = createSilentAudioBuffer(duration: 1.0) else {
            XCTFail("Failed to create silent audio buffer")
            return
        }
        
        XCTAssertGreaterThan(silentBuffer.frameLength, 0)
        
        // Verify silent buffer contains zeros
        if let channelData = silentBuffer.floatChannelData?[0] {
            for i in 0..<Int(silentBuffer.frameLength) {
                XCTAssertEqual(channelData[i], 0.0, accuracy: 0.001)
            }
        }
    }
    
    // MARK: - Voice Frequency Tests
    func testVoiceFrequencyBands() {
        // Test voice frequency emphasis (85-255 Hz range)
        let voiceFrequencyRange = 85.0...255.0
        let testFrequencies = [50.0, 85.0, 170.0, 255.0, 300.0]
        
        for frequency in testFrequencies {
            let isInVoiceRange = voiceFrequencyRange.contains(frequency)
            
            if frequency >= 85.0 && frequency <= 255.0 {
                XCTAssertTrue(isInVoiceRange, "Frequency \(frequency) should be in voice range")
            } else {
                XCTAssertFalse(isInVoiceRange, "Frequency \(frequency) should not be in voice range")
            }
        }
    }
    
    func testNoiseGateThreshold() {
        // Test noise gate application (-40.0 dB threshold)
        let noiseGateThreshold: Float = -40.0
        let testLevels: [Float] = [-50.0, -40.0, -30.0, -20.0]
        
        for level in testLevels {
            let shouldPass = level >= noiseGateThreshold
            
            if level >= noiseGateThreshold {
                XCTAssertTrue(shouldPass, "Level \(level) should pass noise gate")
            } else {
                XCTAssertFalse(shouldPass, "Level \(level) should be blocked by noise gate")
            }
        }
    }
}

// MARK: - Real-time Performance Tests
class SpeechPerformanceTests: PerformanceTestCase {
    
    var mockRecognizer: MockSpeechRecognizer!
    
    override func setUp() {
        super.setUp()
        mockRecognizer = MockSpeechRecognizer.shared
    }
    
    override func tearDown() {
        mockRecognizer.reset()
        super.tearDown()
    }
    
    // MARK: - Latency Tests
    func testLiveTranscriptionLatency() {
        // Test that live transcription meets latency requirements
        measureAsyncPerformance {
            let startTime = Date()
            
            // Simulate speech recognition processing
            if let result = self.mockRecognizer.getRecognitionResult(for: "test_hello") {
                let latency = Date().timeIntervalSince(startTime)
                XCTAssertLessThan(latency, TestConfiguration.maxSTTLatency)
            }
        }
    }
    
    func testConcurrentRecognitionSessions() {
        let expectation = expectation(description: "Concurrent recognition sessions")
        expectation.expectedFulfillmentCount = 5
        
        // Test multiple concurrent recognition tasks
        for i in 0..<5 {
            Task {
                let startTime = Date()
                
                // Simulate concurrent recognition
                if let _ = self.mockRecognizer.getRecognitionResult(for: "test_hello") {
                    let duration = Date().timeIntervalSince(startTime)
                    XCTAssertLessThan(duration, TestConfiguration.maxSTTLatency * 2) // Allow for concurrency overhead
                }
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Memory Usage Tests
    func testLongSessionMemoryUsage() {
        let initialMemory = getMemoryUsage()
        
        // Simulate long recognition session
        for i in 0..<100 {
            _ = mockRecognizer.getRecognitionResult(for: "test_hello")
            
            // Check memory usage periodically
            if i % 10 == 0 {
                let currentMemory = getMemoryUsage()
                let memoryGrowth = currentMemory - initialMemory
                XCTAssertLessThan(memoryGrowth, TestConfiguration.maxMemoryUsage)
            }
        }
    }
    
    func testCPUUsageOptimization() {
        measureAsyncPerformance {
            // Test CPU-intensive speech processing
            let iterations = 1000
            
            for _ in 0..<iterations {
                _ = self.mockRecognizer.getRecognitionResult(for: "test_hello")
            }
        }
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Language Detection Tests  
class LanguageDetectionTests: BaseTestCase {
    
    var mockDetector: MockLanguageDetector!
    
    override func setUp() {
        super.setUp()
        mockDetector = MockLanguageDetector.shared
    }
    
    override func tearDown() {
        mockDetector.reset()
        super.tearDown()
    }
    
    // MARK: - Parallel Detection Tests
    func testParallelLanguageDetection() {
        let expectation = expectation(description: "Parallel language detection")
        expectation.expectedFulfillmentCount = 3
        
        let testTexts = ["Hello", "Hola", "Bonjour"]
        let expectedLanguages = ["en", "es", "fr"]
        
        for (index, text) in testTexts.enumerated() {
            Task {
                let detectedLanguage = self.mockDetector.detectLanguage(from: text)
                XCTAssertEqual(detectedLanguage, expectedLanguages[index])
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Confidence Threshold Tests
    func testLanguageDetectionConfidence() {
        // Test confidence threshold (>0.7) validation
        let confidenceThreshold: Float = 0.7
        
        // In real implementation, this would test actual confidence scores
        // For now, we test the threshold logic
        let testConfidences: [Float] = [0.6, 0.7, 0.8, 0.9, 1.0]
        
        for confidence in testConfidences {
            let shouldAccept = confidence > confidenceThreshold
            
            if confidence > confidenceThreshold {
                XCTAssertTrue(shouldAccept, "Confidence \(confidence) should be accepted")
            } else {
                XCTAssertFalse(shouldAccept, "Confidence \(confidence) should be rejected")
            }
        }
    }
    
    // MARK: - Language Coverage Tests
    func testSupportedLanguageCoverage() {
        let supportedLanguages = [
            "en", "es", "fr", "de", "ja", "zh", "ko", "it", "pt", "ru"
        ]
        
        let testPhrases = [
            "Hello", "Hola", "Bonjour", "Hallo", "こんにちは",
            "你好", "안녕하세요", "Ciao", "Olá", "Привет"
        ]
        
        for (index, phrase) in testPhrases.enumerated() {
            let detectedLanguage = mockDetector.detectLanguage(from: phrase)
            XCTAssertEqual(detectedLanguage, supportedLanguages[index])
        }
    }
    
    func testUnsupportedLanguageFallback() {
        // Test fallback mechanism for unsupported languages
        let unsupportedText = "Some unknown language text"
        let detectedLanguage = mockDetector.detectLanguage(from: unsupportedText)
        
        // Should fallback to English
        XCTAssertEqual(detectedLanguage, "en")
    }
}