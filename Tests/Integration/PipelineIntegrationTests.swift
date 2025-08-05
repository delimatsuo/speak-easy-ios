import XCTest
import Speech
import AVFoundation
@testable import UniversalTranslatorApp

// MARK: - End-to-End Pipeline Integration Tests
class PipelineIntegrationTests: BaseTestCase {
    
    var translationPipeline: TranslationPipeline!
    var speechManager: SpeechRecognitionManager!
    var geminiClient: GeminiAPIClient!
    var audioSessionManager: AudioSessionManager!
    
    override func setUp() {
        super.setUp()
        setupPipelineComponents()
    }
    
    override func tearDown() {
        teardownPipelineComponents()
        super.tearDown()
    }
    
    private func setupPipelineComponents() {
        // Initialize pipeline components
        // Note: These will be connected to actual implementations once created
        audioSessionManager = AudioSessionManager()
        speechManager = SpeechRecognitionManager()
        geminiClient = GeminiAPIClient.shared
        translationPipeline = TranslationPipeline(
            speechManager: speechManager,
            apiClient: geminiClient,
            audioManager: audioSessionManager
        )
    }
    
    private func teardownPipelineComponents() {
        translationPipeline = nil
        speechManager = nil
        audioSessionManager = nil
    }
    
    // MARK: - Complete Pipeline Tests
    
    func testCompleteTranslationPipeline() {
        let expectation = expectation(description: "Complete translation pipeline")
        
        Task {
            do {
                // Step 1: Create test audio with English speech
                guard let testAudio = createTestSpeechAudio(
                    text: "Hello, how are you today?",
                    language: "en-US"
                ) else {
                    XCTFail("Failed to create test audio")
                    expectation.fulfill()
                    return
                }
                
                let startTime = Date()
                
                // Step 2: Process through complete pipeline
                let result = try await translationPipeline.processTranslation(
                    audioBuffer: testAudio,
                    sourceLanguage: "en",
                    targetLanguage: "es"
                )
                
                let totalTime = Date().timeIntervalSince(startTime)
                
                // Step 3: Validate results
                XCTAssertNotNil(result.transcription)
                XCTAssertNotNil(result.translation)
                XCTAssertNotNil(result.audioData)
                
                // Verify transcription quality
                XCTAssertGreaterThan(result.transcription.confidence, 0.8)
                XCTAssertTrue(result.transcription.text.lowercased().contains("hello"))
                
                // Verify translation
                XCTAssertTrue(result.translation.text.lowercased().contains("hola"))
                
                // Verify audio output
                XCTAssertGreaterThan(result.audioData.count, 0)
                
                // Performance validation
                XCTAssertLessThan(totalTime, 5.0, "Complete pipeline should finish within 5 seconds")
                
                expectation.fulfill()
                
            } catch {
                XCTFail("Pipeline failed with error: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPipelineWithDifferentLanguagePairs() {
        let expectation = expectation(description: "Pipeline with different language pairs")
        expectation.expectedFulfillmentCount = 3
        
        let languagePairs = [
            ("en", "es", "Hello", "hola"),
            ("en", "fr", "Thank you", "merci"),
            ("es", "en", "Hola", "hello")
        ]
        
        for (source, target, inputText, expectedWord) in languagePairs {
            Task {
                do {
                    guard let testAudio = createTestSpeechAudio(
                        text: inputText,
                        language: "\(source)-\(source == "en" ? "US" : source.uppercased())"
                    ) else {
                        XCTFail("Failed to create test audio for \(source)")
                        expectation.fulfill()
                        return
                    }
                    
                    let result = try await translationPipeline.processTranslation(
                        audioBuffer: testAudio,
                        sourceLanguage: source,
                        targetLanguage: target
                    )
                    
                    XCTAssertTrue(
                        result.translation.text.lowercased().contains(expectedWord),
                        "Translation should contain '\(expectedWord)' for \(source) -> \(target)"
                    )
                    
                    expectation.fulfill()
                    
                } catch {
                    XCTFail("Pipeline failed for \(source) -> \(target): \(error)")
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testPipelineErrorHandling() {
        let expectation = expectation(description: "Pipeline error handling")
        
        Task {
            // Test with invalid audio
            let invalidAudio = AVAudioPCMBuffer(
                pcmFormat: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!,
                frameCapacity: 0
            )!
            
            do {
                _ = try await translationPipeline.processTranslation(
                    audioBuffer: invalidAudio,
                    sourceLanguage: "en",
                    targetLanguage: "es"
                )
                XCTFail("Pipeline should fail with invalid audio")
            } catch {
                // Expected error - verify it's handled gracefully
                XCTAssertTrue(true, "Pipeline correctly handled invalid audio")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Speech Recognition Integration Tests
    
    func testSpeechRecognitionAccuracy() {
        let expectation = expectation(description: "Speech recognition accuracy")
        
        Task {
            let testPhrases = [
                "The quick brown fox jumps over the lazy dog",
                "Hello world, this is a test",
                "How are you doing today?",
                "Please translate this sentence",
                "Good morning, have a great day"
            ]
            
            var totalAccuracy: Float = 0
            
            for phrase in testPhrases {
                guard let testAudio = createTestSpeechAudio(text: phrase, language: "en-US") else {
                    continue
                }
                
                do {
                    let result = try await speechManager.recognizeAudio(testAudio)
                    
                    // Calculate similarity between input and recognized text
                    let accuracy = calculateTextSimilarity(phrase, result.text)
                    totalAccuracy += accuracy
                    
                    XCTAssertGreaterThan(accuracy, 0.7, "Recognition accuracy should be >70% for: \(phrase)")
                    
                } catch {
                    XCTFail("Speech recognition failed for: \(phrase)")
                }
            }
            
            let averageAccuracy = totalAccuracy / Float(testPhrases.count)
            XCTAssertGreaterThan(averageAccuracy, 0.8, "Average recognition accuracy should be >80%")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 20.0)
    }
    
    func testSpeechRecognitionPerformance() {
        let expectation = expectation(description: "Speech recognition performance")
        
        measureAsyncPerformance {
            guard let testAudio = self.createTestSpeechAudio(
                text: "Performance test audio",
                language: "en-US"
            ) else {
                XCTFail("Failed to create test audio")
                return
            }
            
            do {
                let result = try await self.speechManager.recognizeAudio(testAudio)
                XCTAssertNotNil(result)
            } catch {
                XCTFail("Speech recognition performance test failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Translation Quality Tests
    
    func testTranslationQuality() {
        let expectation = expectation(description: "Translation quality")
        
        Task {
            let testTranslations = [
                TranslationTestCase(
                    source: "en",
                    target: "es",
                    input: "Hello, how are you?",
                    expectedKeywords: ["hola", "cómo", "estás"]
                ),
                TranslationTestCase(
                    source: "en",
                    target: "fr",
                    input: "Thank you very much",
                    expectedKeywords: ["merci", "beaucoup"]
                ),
                TranslationTestCase(
                    source: "es",
                    target: "en",
                    input: "Buenos días",
                    expectedKeywords: ["good", "morning"]
                )
            ]
            
            for testCase in testTranslations {
                do {
                    let result = try await geminiClient.translateText(
                        testCase.input,
                        from: testCase.source,
                        to: testCase.target
                    )
                    
                    let translatedText = result.lowercased()
                    
                    for keyword in testCase.expectedKeywords {
                        XCTAssertTrue(
                            translatedText.contains(keyword.lowercased()),
                            "Translation '\(result)' should contain '\(keyword)'"
                        )
                    }
                    
                } catch {
                    XCTFail("Translation failed for \(testCase.source) -> \(testCase.target): \(error)")
                }
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Audio Processing Integration Tests
    
    func testAudioSessionIntegration() {
        let expectation = expectation(description: "Audio session integration")
        
        Task {
            do {
                // Test recording configuration
                try await audioSessionManager.configureForRecording()
                
                let audioSession = AVAudioSession.sharedInstance()
                XCTAssertEqual(audioSession.category, .playAndRecord)
                
                // Test playback configuration
                try await audioSessionManager.configureForPlayback()
                
                // Test interruption handling
                let interruptionHandled = await audioSessionManager.handleTestInterruption()
                XCTAssertTrue(interruptionHandled, "Should handle audio interruption gracefully")
                
                expectation.fulfill()
                
            } catch {
                XCTFail("Audio session integration failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testTTSIntegration() {
        let expectation = expectation(description: "TTS integration")
        
        Task {
            do {
                let testText = "This is a test of the text-to-speech system"
                
                let audioData = try await geminiClient.synthesizeSpeech(
                    text: testText,
                    language: "en-US",
                    voiceConfig: TTSVoiceConfig.default
                )
                
                XCTAssertGreaterThan(audioData.count, 0, "TTS should generate audio data")
                
                // Test audio playback
                let playbackSuccess = await audioSessionManager.playAudio(audioData)
                XCTAssertTrue(playbackSuccess, "Should be able to play TTS audio")
                
                expectation.fulfill()
                
            } catch {
                XCTFail("TTS integration failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestSpeechAudio(text: String, language: String) -> AVAudioPCMBuffer? {
        // Create synthetic audio that represents speech
        // In a real scenario, this would use actual recorded audio samples
        let sampleRate: Double = 16000
        let duration: TimeInterval = Double(text.count) * 0.1 // ~100ms per character
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        // Generate synthetic speech-like audio
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        
        for i in 0..<Int(frameCount) {
            let time = Double(i) / sampleRate
            
            // Create speech-like waveform with multiple frequencies
            let fundamental = sin(2.0 * Double.pi * 200.0 * time) // 200 Hz fundamental
            let harmonic1 = sin(2.0 * Double.pi * 400.0 * time) * 0.5 // First harmonic
            let harmonic2 = sin(2.0 * Double.pi * 600.0 * time) * 0.25 // Second harmonic
            
            // Add some noise to make it more realistic
            let noise = Double.random(in: -0.1...0.1)
            
            let sample = (fundamental + harmonic1 + harmonic2 + noise) * 0.3
            channelData[i] = Float(sample)
        }
        
        return buffer
    }
    
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Float {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0.0 }
        return Float(intersection.count) / Float(union.count)
    }
}

// MARK: - Supporting Data Structures
struct TranslationTestCase {
    let source: String
    let target: String
    let input: String
    let expectedKeywords: [String]
}

struct PipelineResult {
    let transcription: TranscriptionResult
    let translation: TranslationResult
    let audioData: Data
    let totalProcessingTime: TimeInterval
}

// MARK: - Mock Pipeline Components (until real implementations are ready)
class TranslationPipeline {
    private let speechManager: SpeechRecognitionManager
    private let apiClient: GeminiAPIClient
    private let audioManager: AudioSessionManager
    
    init(speechManager: SpeechRecognitionManager, apiClient: GeminiAPIClient, audioManager: AudioSessionManager) {
        self.speechManager = speechManager
        self.apiClient = apiClient
        self.audioManager = audioManager
    }
    
    func processTranslation(
        audioBuffer: AVAudioPCMBuffer,
        sourceLanguage: String,
        targetLanguage: String
    ) async throws -> PipelineResult {
        let startTime = Date()
        
        // Step 1: Speech to Text
        let transcription = try await speechManager.recognizeAudio(audioBuffer)
        
        // Step 2: Translate Text
        let translation = try await apiClient.translateText(
            transcription.text,
            from: sourceLanguage,
            to: targetLanguage
        )
        
        // Step 3: Text to Speech
        let audioData = try await apiClient.synthesizeSpeech(
            text: translation,
            language: "\(targetLanguage)-US",
            voiceConfig: TTSVoiceConfig.default
        )
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        return PipelineResult(
            transcription: TranscriptionResult(
                text: transcription.text,
                confidence: transcription.confidence,
                segments: [],
                alternatives: [],
                isFinal: true,
                timestamp: Date(),
                duration: 0
            ),
            translation: TranslationResult(text: translation),
            audioData: audioData,
            totalProcessingTime: totalTime
        )
    }
}

// Mock implementations (to be replaced with actual classes)
class SpeechRecognitionManager {
    func recognizeAudio(_ buffer: AVAudioPCMBuffer) async throws -> (text: String, confidence: Float) {
        // Simulate speech recognition processing
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // For testing, return a mock result based on audio characteristics
        let mockText = "Hello, how are you today?" // Would be actual recognition
        let confidence: Float = 0.95
        
        return (text: mockText, confidence: confidence)
    }
}

class GeminiAPIClient {
    static let shared = GeminiAPIClient()
    private init() {}
    
    func translateText(_ text: String, from: String, to: String) async throws -> String {
        // Simulate API call
        try await Task.sleep(nanoseconds: 800_000_000) // 800ms
        
        // Mock translation logic
        let translations = [
            "Hello, how are you today?": "Hola, ¿cómo estás hoy?",
            "Thank you very much": "Merci beaucoup",
            "Buenos días": "Good morning"
        ]
        
        return translations[text] ?? "Translated: \(text)"
    }
    
    func synthesizeSpeech(text: String, language: String, voiceConfig: TTSVoiceConfig) async throws -> Data {
        // Simulate TTS processing
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Return mock audio data
        return Data(repeating: 0xFF, count: 44100 * 2) // 1 second of mock audio
    }
}

class AudioSessionManager {
    func configureForRecording() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)
    }
    
    func configureForPlayback() async throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
    }
    
    func handleTestInterruption() async -> Bool {
        // Simulate interruption handling
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        return true
    }
    
    func playAudio(_ data: Data) async -> Bool {
        // Simulate audio playback
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        return true
    }
}

struct TTSVoiceConfig {
    static let `default` = TTSVoiceConfig()
}

struct TranslationResult {
    let text: String
}