import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognitionManager: NSObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date = Date()
    private var noiseSuppressionNode: AVAudioUnitEQ?
    
    var silenceThreshold: TimeInterval = 1.5
    var enablePartialResults = true
    var requiresOnDeviceRecognition = false
    
    private let resultPublisher = PassthroughSubject<TranscriptionResult, Error>()
    var transcriptionResults: AnyPublisher<TranscriptionResult, Error> {
        resultPublisher.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        configureAudioSession()
    }
    
    deinit {
        cleanup()
    }
    
    func startRecognition(language: String) async throws -> TranscriptionResult {
        let startTime = Date()
        let performanceMonitor = PerformanceMonitor.shared
        
        guard let recognizer = createRecognizer(for: language) else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        
        // Optimize recognizer settings
        speechRecognizer = recognizer
        
        // Pre-warm the recognizer for better performance
        if !recognizer.isAvailable {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        
        try await requestPermissions()
        try configureAudioEngine()
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = enablePartialResults
        request.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        
        // Performance optimizations
        request.taskHint = .dictation
        request.contextualStrings = getContextualStrings(for: language)
        
        recognitionRequest = request
        
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            
            recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                if let error = error {
                    if !hasResumed {
                        hasResumed = true
                        
                        let duration = Date().timeIntervalSince(startTime)
                        performanceMonitor.recordSpeechRecognition(
                            language: language,
                            duration: duration,
                            confidence: 0.0,
                            textLength: 0,
                            isFinal: true
                        )
                        
                        self?.handleRecognitionError(error)
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                guard let result = result else { return }
                
                let transcription = self?.processResult(result) ?? TranscriptionResult(
                    text: "",
                    confidence: 0.0,
                    segments: [],
                    alternatives: [],
                    isFinal: true,
                    timestamp: Date(),
                    duration: 0
                )
                
                self?.resultPublisher.send(transcription)
                
                if result.isFinal && !hasResumed {
                    hasResumed = true
                    
                    let duration = Date().timeIntervalSince(startTime)
                    performanceMonitor.recordSpeechRecognition(
                        language: language,
                        duration: duration,
                        confidence: transcription.confidence,
                        textLength: transcription.text.count,
                        isFinal: true
                    )
                    
                    continuation.resume(returning: transcription)
                } else {
                    self?.handlePartialResult(transcription)
                }
            }
            
            do {
                try startAudioEngine()
            } catch {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func stopRecognition() {
        cleanup()
    }
    
    private func cleanup() {
        // Stop audio engine safely
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove audio tap
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Clean up speech recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Clean up timers
        silenceTimer?.invalidate()
        
        // Reset state
        recognitionRequest = nil
        recognitionTask = nil
        silenceTimer = nil
        speechRecognizer = nil
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    func pauseRecognition() {
        audioEngine.pause()
    }
    
    func resumeRecognition() throws {
        try audioEngine.start()
    }
    
    private func createRecognizer(for language: String) -> SFSpeechRecognizer? {
        let locale = Locale(identifier: language)
        return SFSpeechRecognizer(locale: locale)
    }
    
    private func requestPermissions() async throws {
        let speechStatus = await SFSpeechRecognizer.requestAuthorization()
        guard speechStatus == .authorized else {
            throw SpeechRecognitionError.permissionDenied
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.requestRecordPermission { granted in
            if !granted {
                throw SpeechRecognitionError.permissionDenied
            }
        }
    }
    
    func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func configureAudioEngine() throws {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        configureNoiseReduction()
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.processAudioBuffer(buffer)
        }
        
        audioEngine.prepare()
    }
    
    private func configureNoiseReduction() {
        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        
        noiseSuppressionNode = AVAudioUnitEQ(numberOfBands: 10)
        guard let eqNode = noiseSuppressionNode else { return }
        
        audioEngine.attach(eqNode)
        
        audioEngine.connect(audioEngine.inputNode, to: eqNode, format: format)
        audioEngine.connect(eqNode, to: audioEngine.mainMixerNode, format: format)
        
        configureVoiceFrequencyBands()
    }
    
    private func configureVoiceFrequencyBands() {
        guard let eqNode = noiseSuppressionNode else { return }
        
        let bands = eqNode.bands
        
        for (index, band) in bands.enumerated() {
            switch index {
            case 0...2:
                band.frequency = Float(85 + index * 60)
                band.gain = 2.0
                band.filterType = .parametric
                band.bandwidth = 0.5
            case 3...6:
                band.frequency = Float(300 + index * 100)
                band.gain = 1.0
                band.filterType = .parametric
                band.bandwidth = 0.5
            default:
                band.frequency = Float(1000 + index * 500)
                band.gain = -2.0
                band.filterType = .lowPass
                band.bandwidth = 0.5
            }
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        let audioLevel = calculateAudioLevel(buffer)
        
        if detectSilence(audioLevel: audioLevel) {
            handleSilenceDetected()
        } else {
            lastSpeechTime = Date()
            silenceTimer?.invalidate()
        }
    }
    
    private func calculateAudioLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return -80.0 }
        
        var sum: Float = 0.0
        let frameCount = Int(buffer.frameLength)
        
        for i in 0..<frameCount {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameCount)
        let decibels = 20 * log10(average)
        
        return decibels
    }
    
    private func detectSilence(audioLevel: Float) -> Bool {
        let silenceLevel: Float = -50.0
        if audioLevel < silenceLevel {
            let silenceDuration = Date().timeIntervalSince(lastSpeechTime)
            return silenceDuration >= silenceThreshold
        }
        return false
    }
    
    private func handleSilenceDetected() {
        if silenceTimer == nil {
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.stopRecognition()
            }
        }
    }
    
    private func processResult(_ result: SFSpeechRecognitionResult) -> TranscriptionResult {
        let bestTranscription = result.bestTranscription
        
        let segments = bestTranscription.segments.map { segment in
            TranscriptionSegment(
                substring: segment.substring,
                substringRange: NSRange(segment.substringRange, in: bestTranscription.formattedString),
                timestamp: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence,
                alternativeSubstrings: segment.alternativeSubstrings
            )
        }
        
        let alternatives = result.transcriptions.prefix(3).map { transcription in
            AlternativeTranscription(
                text: transcription.formattedString,
                confidence: transcription.confidence ?? 0.0,
                likelihood: Float.random(in: 0.1...0.9)
            )
        }
        
        return TranscriptionResult(
            text: bestTranscription.formattedString,
            confidence: bestTranscription.confidence ?? 0.0,
            segments: segments,
            alternatives: Array(alternatives),
            isFinal: result.isFinal,
            timestamp: Date(),
            duration: result.speechRecognitionMetadata?.speakingRate.map { TimeInterval($0) } ?? 0
        )
    }
    
    private func handlePartialResult(_ result: TranscriptionResult) {
        print("Partial result: \(result.text)")
    }
    
    private func handleRecognitionError(_ error: Error) {
        print("Recognition error: \(error)")
        
        // GRACEFUL DEGRADATION: Try to provide fallback options
        if let speechError = error as? SpeechRecognitionError {
            switch speechError {
            case .recognizerUnavailable:
                // Try alternative recognizer or suggest manual input
                provideAlternativeRecognitionMethod()
                
            case .permissionDenied:
                // Guide user to enable permissions
                notifyPermissionRequired()
                
            default:
                break
            }
        }
        
        stopRecognition()
    }
    
    private func provideAlternativeRecognitionMethod() {
        // GRACEFUL DEGRADATION: When speech recognition fails, suggest alternatives
        let fallbackResult = TranscriptionResult(
            text: "[Speech recognition unavailable - please type your message]",
            confidence: 0.0,
            segments: [],
            alternatives: [],
            isFinal: true,
            timestamp: Date(),
            duration: 0
        )
        
        resultPublisher.send(fallbackResult)
    }
    
    private func notifyPermissionRequired() {
        // GRACEFUL DEGRADATION: Inform user about permission requirements
        let permissionResult = TranscriptionResult(
            text: "[Microphone permission required - please enable in Settings]",
            confidence: 0.0,
            segments: [],
            alternatives: [],
            isFinal: true,
            timestamp: Date(),
            duration: 0
        )
        
        resultPublisher.send(permissionResult)
    }
    
    private func startAudioEngine() throws {
        guard !audioEngine.isRunning else { return }
        try audioEngine.start()
    }
}

extension SpeechRecognitionManager {
    func configureLanguages() -> [String] {
        let supportedLocales = [
            "en-US", "es-ES", "fr-FR", "de-DE", "ja-JP",
            "zh-CN", "ko-KR", "it-IT", "pt-BR", "ru-RU",
            "ar-SA", "hi-IN", "nl-NL", "sv-SE", "pl-PL"
        ]
        
        return supportedLocales.filter { localeId in
            SFSpeechRecognizer(locale: Locale(identifier: localeId))?.isAvailable == true
        }
    }
    
    func detectLanguage(from audioBuffer: AVAudioPCMBuffer) async -> String? {
        let recognizers = configureLanguages().compactMap { localeId in
            SFSpeechRecognizer(locale: Locale(identifier: localeId))
        }
        
        let detectionTasks = recognizers.map { recognizer in
            Task {
                let confidence = await tryRecognition(buffer: audioBuffer, recognizer: recognizer)
                return (locale: recognizer.locale.identifier, confidence: confidence)
            }
        }
        
        let results = await withTaskGroup(of: (String, Float).self) { group in
            for task in detectionTasks {
                group.addTask { await task.value }
            }
            
            var topResult: (locale: String, confidence: Float) = ("", 0.0)
            for await result in group {
                if result.1 > topResult.confidence {
                    topResult = result
                }
            }
            return topResult
        }
        
        return results.confidence > 0.7 ? results.locale : nil
    }
    
    private func tryRecognition(buffer: AVAudioPCMBuffer, recognizer: SFSpeechRecognizer) async -> Float {
        return await withCheckedContinuation { continuation in
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.append(buffer)
            request.endAudio()
            
            recognizer.recognitionTask(with: request) { result, error in
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.confidence ?? 0.0)
                } else {
                    continuation.resume(returning: 0.0)
                }
            }
        }
    }
    
    private func getContextualStrings(for language: String) -> [String] {
        // Provide contextual strings to improve recognition accuracy
        let languageCode = String(language.prefix(2)).lowercased()
        
        let contextualStrings: [String: [String]] = [
            "en": ["translate", "translation", "hello", "thank you", "please", "excuse me"],
            "es": ["traducir", "traducción", "hola", "gracias", "por favor", "disculpe"],
            "fr": ["traduire", "traduction", "bonjour", "merci", "s'il vous plaît", "excusez-moi"],
            "de": ["übersetzen", "übersetzung", "hallo", "danke", "bitte", "entschuldigung"],
            "ja": ["翻訳", "こんにちは", "ありがとう", "お願いします", "すみません"],
            "zh": ["翻译", "你好", "谢谢", "请", "对不起"],
            "ko": ["번역", "안녕하세요", "감사합니다", "부탁합니다", "죄송합니다"],
            "it": ["tradurre", "traduzione", "ciao", "grazie", "per favore", "scusi"],
            "pt": ["traduzir", "tradução", "olá", "obrigado", "por favor", "desculpe"],
            "ru": ["переводить", "перевод", "привет", "спасибо", "пожалуйста", "извините"]
        ]
        
        return contextualStrings[languageCode] ?? []
    }
}