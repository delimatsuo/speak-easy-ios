import Foundation
import SwiftUI
import AVFoundation
import Speech
import Combine

@MainActor
class TranslationViewModel: ObservableObject {
    @Published var sourceLanguage: Language = Language.defaultSource
    @Published var targetLanguage: Language = Language.defaultTarget
    @Published var recordingState: RecordingState = .idle
    @Published var transcribedText: String = ""
    @Published var translatedText: String = ""
    @Published var currentError: TranslationError?
    @Published var isTextInputMode: Bool = false
    @Published var audioLevel: Double = 0.0
    @Published var translationHistory: [TranslationResult] = []
    
    // Real backend services
    private let speechRecognizer = SpeechRecognitionManager.shared
    private let translationService = TranslationService.shared
    private let audioService = AudioService.shared
    private let networkMonitor = NetworkMonitor.shared
    private let performanceMonitor = PerformanceMonitor.shared
    
    // Dynamic Island support
    @available(iOS 16.1, *)
    private let liveActivityManager = TranslationLiveActivityManager.shared
    
    // Combine cancellables
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupBindings()
        requestPermissions()
    }
    
    // MARK: - UI Actions
    
    func swapLanguages() {
        withAnimation(.easeInOut(duration: 0.3)) {
            let temp = sourceLanguage
            sourceLanguage = targetLanguage
            targetLanguage = temp
        }
        
        HapticManager.shared.mediumImpact()
        
        // Update speech recognizer language
        speechRecognizer.currentLanguage = sourceLanguage.code
    }
    
    func startRecording() {
        guard recordingState == .idle else { return }
        
        recordingState = .recording
        transcribedText = ""
        translatedText = ""
        currentError = nil
        
        HapticManager.shared.heavyImpact()
        
        // Start Dynamic Island Live Activity
        if #available(iOS 16.1, *) {
            liveActivityManager.startActivity(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            liveActivityManager.updateActivity(state: .recording)
        }
        
        Task {
            await performSpeechRecognition()
        }
    }
    
    func stopRecording() {
        guard recordingState == .recording else { return }
        
        recordingState = .processing
        speechRecognizer.stopRecognition()
        
        HapticManager.shared.mediumImpact()
        
        // Update Dynamic Island
        if #available(iOS 16.1, *) {
            liveActivityManager.updateActivity(state: .processing)
        }
        
        if !transcribedText.isEmpty {
            Task {
                await translateText(transcribedText)
            }
        } else {
            recordingState = .error("No speech detected")
            if #available(iOS 16.1, *) {
                liveActivityManager.updateActivity(state: .error)
            }
        }
    }
    
    func translateText(_ text: String) async {
        recordingState = .processing
        
        // Update Dynamic Island
        if #available(iOS 16.1, *) {
            liveActivityManager.updateActivity(
                state: .translating,
                originalText: text
            )
        }
        
        // Record performance
        let startTime = Date()
        
        do {
            let result = try await translationService.translate(
                text: text,
                from: sourceLanguage,
                to: targetLanguage
            )
            
            translatedText = result.translatedText
            
            let translationResult = TranslationResult(
                originalText: text,
                translatedText: result.translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            
            translationHistory.insert(translationResult, at: 0)
            
            recordingState = .idle
            HapticManager.shared.lightImpact()
            
            // Update Dynamic Island with completed translation
            if #available(iOS 16.1, *) {
                liveActivityManager.updateActivity(
                    state: .completed,
                    originalText: text,
                    translatedText: result.translatedText,
                    confidence: result.confidence
                )
                
                // End activity after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.liveActivityManager.endActivity()
                }
            }
            
            // Record successful translation performance
            let duration = Date().timeIntervalSince(startTime)
            performanceMonitor.recordTranslationComplete(
                duration: duration,
                textLength: text.count,
                success: true
            )
            
            if UserDefaults.standard.bool(forKey: "autoPlayTranslation") {
                await playTranslation()
            }
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            performanceMonitor.recordTranslationComplete(
                duration: duration,
                textLength: text.count,
                success: false,
                error: error
            )
            
            if let translationError = error as? TranslationError {
                currentError = translationError
                recordingState = .error(translationError.localizedDescription)
            } else {
                currentError = .apiError(error.localizedDescription)
                recordingState = .error("Translation failed")
            }
            
            // Update Dynamic Island with error
            if #available(iOS 16.1, *) {
                liveActivityManager.updateActivity(state: .error)
            }
        }
    }
    
    func playTranslation() async {
        guard !translatedText.isEmpty else { return }
        
        recordingState = .playback
        
        do {
            try await audioService.speak(text: translatedText, language: targetLanguage)
            recordingState = .idle
        } catch {
            recordingState = .idle
        }
    }
    
    func clearCurrentTranslation() {
        withAnimation {
            transcribedText = ""
            translatedText = ""
            currentError = nil
            recordingState = .idle
        }
    }
    
    func retryLastTranslation() {
        guard !transcribedText.isEmpty else { return }
        
        Task {
            await translateText(transcribedText)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind to speech recognition updates
        speechRecognizer.transcriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleSpeechRecognitionError(error)
                    }
                },
                receiveValue: { [weak self] result in
                    self?.handleTranscriptionResult(result)
                }
            )
            .store(in: &cancellables)
        
        // Bind to audio level updates
        speechRecognizer.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: \.audioLevel, on: self)
            .store(in: &cancellables)
        
        // Bind to recording state updates
        speechRecognizer.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if !isRecording && self?.recordingState == .recording {
                    self?.stopRecording()
                }
            }
            .store(in: &cancellables)
        
        // Bind to silence detection
        speechRecognizer.silenceDetectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] silenceDetected in
                if silenceDetected && self?.recordingState == .recording {
                    self?.stopRecording()
                }
            }
            .store(in: &cancellables)
        
        // Bind to translation updates
        translationService.translationPublisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.currentError = error
                        self?.recordingState = .error(error.localizedDescription)
                    }
                },
                receiveValue: { [weak self] result in
                    self?.translatedText = result.translatedText
                    self?.translationHistory.insert(result, at: 0)
                    self?.recordingState = .idle
                }
            )
            .store(in: &cancellables)
        
        // Bind to network status
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                if !isConnected && self?.recordingState == .processing {
                    self?.currentError = .noInternet
                    self?.recordingState = .error("No internet connection")
                }
            }
            .store(in: &cancellables)
    }
    
    private func performSpeechRecognition() async {
        do {
            let success = try await speechRecognizer.startRecognition(language: sourceLanguage.code)
            if !success {
                recordingState = .error("Failed to start speech recognition")
            }
        } catch {
            handleSpeechRecognitionError(error)
        }
    }
    
    private func handleTranscriptionResult(_ result: TranscriptionResult) {
        transcribedText = result.text
        
        // If final result and we have text, start translation
        if result.isFinal && !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                await translateText(result.text)
            }
        }
    }
    
    private func handleSpeechRecognitionError(_ error: Error) {
        let errorMessage: String
        
        if let speechError = error as? SpeechRecognitionError {
            switch speechError {
            case .permissionDenied:
                errorMessage = "Microphone permission required"
            case .recognizerUnavailable:
                errorMessage = "Speech recognition unavailable"
            case .noSpeechDetected:
                errorMessage = "No speech detected"
            case .audioEngineFailure:
                errorMessage = "Audio system error"
            case .generalError(let message):
                errorMessage = message
            }
        } else {
            errorMessage = error.localizedDescription
        }
        
        currentError = .speechRecognitionFailed
        recordingState = .error(errorMessage)
    }
    
    private func requestPermissions() {
        Task {
            // Request speech recognition permission
            let speechStatus = await SFSpeechRecognizer.requestAuthorization()
            
            // Request microphone permission
            let micStatus = await AVAudioSession.sharedInstance().requestRecordPermission()
            
            await MainActor.run {
                if speechStatus != .authorized || !micStatus {
                    currentError = .speechRecognitionFailed
                }
            }
        }
    }
}

extension TranslationViewModel: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if !available && recordingState == .recording {
            stopRecording()
        }
    }
}