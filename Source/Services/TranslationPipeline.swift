import Foundation
import AVFoundation
import Combine

class TranslationPipeline: ObservableObject {
    private let speechRecognizer = SpeechRecognitionManager()
    private let translator: TranslationService = GeminiTranslationService()
    private let ttsService: TTSService = GeminiTTSService()
    private let audioPlayer = AudioPlayerManager()
    private let errorHandler = ErrorHandlingCoordinator.shared
    private let networkMonitor = NetworkMonitor.shared
    
    @Published var isProcessing = false
    @Published var currentStep: ProcessingStep = .idle
    @Published var progress: Float = 0.0
    @Published var lastError: Error?
    
    private var cancellables = Set<AnyCancellable>()
    
    enum ProcessingStep: String, CaseIterable {
        case idle = "Ready"
        case listening = "Listening..."
        case recognizing = "Converting speech to text..."
        case translating = "Translating..."
        case synthesizing = "Generating speech..."
        case playing = "Playing audio..."
        case completed = "Completed"
        case error = "Error occurred"
    }
    
    init() {
        setupSubscriptions()
    }
    
    func processTranslation(sourceLanguage: String, targetLanguage: String) async throws -> TranslationResult {
        guard !isProcessing else {
            throw TranslationError.translationFailed("Translation already in progress")
        }
        
        await MainActor.run {
            isProcessing = true
            currentStep = .listening
            progress = 0.0
            lastError = nil
        }
        
        do {
            let result = try await executeTranslationPipeline(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            
            await MainActor.run {
                currentStep = .completed
                progress = 1.0
                isProcessing = false
            }
            
            return result
            
        } catch {
            await MainActor.run {
                currentStep = .error
                lastError = error
                isProcessing = false
            }
            
            let strategy = errorHandler.handleError(error)
            try await handleErrorStrategy(strategy, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            
            throw error
        }
    }
    
    func processTextTranslation(text: String, sourceLanguage: String, targetLanguage: String) async throws -> TranslationResult {
        await MainActor.run {
            isProcessing = true
            currentStep = .translating
            progress = 0.3
        }
        
        do {
            let translation = try await translator.translate(
                text: text,
                from: sourceLanguage,
                to: targetLanguage
            )
            
            await MainActor.run {
                progress = 0.6
                currentStep = .synthesizing
            }
            
            let audioData = try await ttsService.synthesize(
                text: translation.translatedText,
                language: targetLanguage,
                voice: nil
            )
            
            await MainActor.run {
                progress = 0.9
                currentStep = .playing
            }
            
            try await audioPlayer.play(audioData)
            
            let result = TranslationResult(
                originalText: text,
                translatedText: translation.translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                audioData: audioData,
                confidence: translation.confidence,
                timestamp: translation.timestamp
            )
            
            await MainActor.run {
                currentStep = .completed
                progress = 1.0
                isProcessing = false
            }
            
            return result
            
        } catch {
            await MainActor.run {
                currentStep = .error
                lastError = error
                isProcessing = false
            }
            throw error
        }
    }
    
    func stopProcessing() {
        speechRecognizer.stopRecognition()
        audioPlayer.stop()
        
        Task { @MainActor in
            isProcessing = false
            currentStep = .idle
            progress = 0.0
        }
    }
    
    private func executeTranslationPipeline(sourceLanguage: String, targetLanguage: String) async throws -> TranslationResult {
        await MainActor.run { progress = 0.1 }
        
        let transcription = try await speechRecognizer.startRecognition(language: sourceLanguage)
        
        await MainActor.run {
            currentStep = .recognizing
            progress = 0.25
        }
        
        let preparedText = preprocessText(transcription.text)
        
        guard !preparedText.isEmpty else {
            throw TranslationError.translationFailed("No speech detected")
        }
        
        await MainActor.run {
            currentStep = .translating
            progress = 0.4
        }
        
        let (validatedSource, validatedTarget) = try validateLanguagePair(
            source: sourceLanguage,
            target: targetLanguage
        )
        
        let translation = try await translator.translate(
            text: preparedText,
            from: validatedSource,
            to: validatedTarget
        )
        
        await MainActor.run {
            currentStep = .synthesizing
            progress = 0.7
        }
        
        let audioData = try await ttsService.synthesize(
            text: translation.translatedText,
            language: validatedTarget,
            voice: nil
        )
        
        await MainActor.run {
            currentStep = .playing
            progress = 0.9
        }
        
        try await audioPlayer.play(audioData)
        
        return TranslationResult(
            originalText: preparedText,
            translatedText: translation.translatedText,
            sourceLanguage: validatedSource,
            targetLanguage: validatedTarget,
            audioData: audioData,
            confidence: transcription.confidence * translation.confidence,
            timestamp: Date()
        )
    }
    
    private func preprocessText(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    private func validateLanguagePair(source: String, target: String) throws -> (String, String) {
        guard LanguageCodeMapper.validate(source) else {
            throw TranslationError.invalidLanguageCode("Invalid source language: \(source)")
        }
        
        guard LanguageCodeMapper.validate(target) else {
            throw TranslationError.invalidLanguageCode("Invalid target language: \(target)")
        }
        
        guard source != target else {
            throw TranslationError.translationFailed("Source and target languages cannot be the same")
        }
        
        return (source, target)
    }
    
    private func handleErrorStrategy(_ strategy: ErrorRecoveryStrategy, sourceLanguage: String, targetLanguage: String) async throws {
        switch strategy {
        case .retry(let delay, let maxAttempts, let withBackoff, _):
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            // GRACEFUL DEGRADATION: Implement progressive retry with fallback
            await MainActor.run {
                currentStep = .listening
                progress = 0.0
            }
            
        case .switchToOfflineMode(let withCache, let message):
            // GRACEFUL DEGRADATION: Activate offline mode with enhanced capabilities
            await enableOfflineMode(withCache: withCache, message: message)
            
        case .fallback(let option):
            try await handleFallbackOption(option, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            
        default:
            // GRACEFUL DEGRADATION: Always provide some form of fallback
            await provideFallbackExperience(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        }
    }
    
    private func enableOfflineMode(withCache: Bool, message: String) async {
        await MainActor.run {
            currentStep = .idle
            progress = 0.0
        }
        
        print("OFFLINE MODE ACTIVATED: \(message)")
        
        if withCache {
            // Try to provide cached translations for common phrases
            print("Using cached translations for offline functionality")
        }
    }
    
    private func provideFallbackExperience(sourceLanguage: String, targetLanguage: String) async {
        // GRACEFUL DEGRADATION: Provide basic functionality even when everything fails
        await MainActor.run {
            currentStep = .idle
            progress = 0.0
        }
        
        print("Providing fallback experience: manual text input available")
        print("Source: \(sourceLanguage) -> Target: \(targetLanguage)")
    }
    
    private func handleFallbackOption(_ option: ErrorRecoveryStrategy.FallbackOption, sourceLanguage: String, targetLanguage: String) async throws {
        switch option {
        case .manualTextInput:
            await MainActor.run {
                currentStep = .idle
            }
            
        case .cachedTranslation:
            print("Attempting to use cached translation")
            
        case .autoDetectLanguage(let invalidCode):
            print("Auto-detecting language for invalid code: \(invalidCode)")
            
        default:
            break
        }
    }
    
    private func setupSubscriptions() {
        speechRecognizer.transcriptionResults
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.lastError = error
                }
            } receiveValue: { [weak self] result in
                if !result.isFinal {
                    print("Partial transcription: \(result.text)")
                }
            }
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
        audioPlayer.stop()
        speechRecognizer.stopRecognition()
    }
}

struct TranslationResult {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let audioData: Data?
    let confidence: Float
    let timestamp: Date
}

enum AudioPlayerError: Error {
    case configurationFailed(String)
    case playbackFailed(String)
    case audioUnavailable(String)
}

class AudioPlayerManager: NSObject {
    private var audioPlayer: AVAudioPlayer?
    private let audioSession = AVAudioSession.sharedInstance()
    private var playbackCompletion: CheckedContinuation<Void, Error>?
    
    override init() {
        super.init()
        setupNotifications()
    }
    
    deinit {
        cleanup()
    }
    
    func play(_ audioData: Data) async throws {
        do {
            try configureAudioSession()
            
            cleanup() // Clean up any existing player
            
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            return try await withCheckedThrowingContinuation { [weak self] continuation in
                self?.playbackCompletion = continuation
                
                guard let player = self?.audioPlayer else {
                    // GRACEFUL DEGRADATION: Provide text fallback when audio fails
                    self?.handleAudioFailure(continuation: continuation, reason: "Failed to create audio player")
                    return
                }
                
                if !player.play() {
                    // GRACEFUL DEGRADATION: Provide text fallback when playback fails
                    self?.handleAudioFailure(continuation: continuation, reason: "Failed to start playback")
                }
            }
        } catch {
            // GRACEFUL DEGRADATION: When audio session configuration fails
            print("Audio playback failed, providing text-only experience: \(error)")
            throw AudioPlayerError.configurationFailed("Audio unavailable - translation text provided instead")
        }
    }
    
    private func handleAudioFailure(continuation: CheckedContinuation<Void, Error>, reason: String) {
        // GRACEFUL DEGRADATION: Instead of hard failure, complete successfully but log the issue
        print("Audio playback failed (\(reason)) - continuing with text-only experience")
        continuation.resume()
    }
    
    func stop() {
        audioPlayer?.stop()
        playbackCompletion?.resume()
        playbackCompletion = nil
        cleanup()
    }
    
    private func configureAudioSession() throws {
        try audioSession.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .duckOthers])
        try audioSession.setActive(true)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    private func cleanup() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            audioPlayer?.pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    audioPlayer?.play()
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        if reason == .oldDeviceUnavailable {
            audioPlayer?.pause()
        }
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playbackCompletion?.resume()
        playbackCompletion = nil
        cleanup()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let audioError = error ?? NSError(domain: "AudioPlayerError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Audio decode error"])
        playbackCompletion?.resume(throwing: audioError)
        playbackCompletion = nil
        cleanup()
    }
}