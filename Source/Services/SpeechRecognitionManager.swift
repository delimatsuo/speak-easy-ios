import Foundation
import Speech
import AVFoundation
import Combine

class SpeechRecognitionManager: NSObject, ObservableObject {
    static let shared = SpeechRecognitionManager()
    
    // MARK: - Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    
    // Configuration
    private var silenceThreshold: TimeInterval = 1.5
    private var enablePartialResults = true
    private var requiresOnDeviceRecognition = false
    
    // Published state
    @Published var isRecording = false
    @Published var audioLevel: Double = 0.0
    @Published var currentLanguage: String = "en-US"
    
    // Publishers
    private let transcriptionSubject = PassthroughSubject<TranscriptionResult, Error>()
    private let silenceDetectionSubject = PassthroughSubject<Bool, Never>()
    
    var transcriptionPublisher: AnyPublisher<TranscriptionResult, Error> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    var silenceDetectedPublisher: AnyPublisher<Bool, Never> {
        silenceDetectionSubject.eraseToAnyPublisher()
    }
    
    // Silence detection
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date = Date()
    private let silenceLevel: Float = -50.0 // dB threshold
    
    override init() {
        super.init()
        configureSilenceDetection()
        setupAudioSession()
    }
    
    // MARK: - Public API
    
    func startRecognition(language: String = "en-US") async throws -> Bool {
        guard !isRecording else { return false }
        
        // Configure for language
        currentLanguage = language
        setupSpeechRecognizer(for: language)
        
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        
        // Request permissions
        let authStatus = await requestPermissions()
        guard authStatus == .authorized else {
            throw SpeechRecognitionError.permissionDenied
        }
        
        try configureAudioSession()
        try startAudioEngine()
        
        await MainActor.run {
            isRecording = true
        }
        
        return true
    }
    
    func stopRecognition() {
        guard isRecording else { return }
        
        stopAudioEngine()
        stopSilenceTimer()
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0.0
        }
    }
    
    func pauseRecognition() {
        recognitionTask?.suspend()
    }
    
    func resumeRecognition() {
        recognitionTask?.resume()
    }
    
    func configureSilenceDetection(threshold: TimeInterval = 1.5) {
        silenceThreshold = max(0.5, min(threshold, 2.0)) // Clamp to 0.5-2.0 seconds
        UserDefaults.standard.set(silenceThreshold, forKey: "silence_threshold")
    }
    
    // MARK: - Private Methods
    
    private func setupSpeechRecognizer(for language: String) {
        let locale = Locale(identifier: language)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self
    }
    
    private func requestPermissions() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    private func configureAudioSession() throws {
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startAudioEngine() throws {
        // Reset if already running
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.audioEngineFailure
        }
        
        recognitionRequest.shouldReportPartialResults = enablePartialResults
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            self?.recognitionRequest?.append(buffer)
            self?.processAudioLevel(from: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        startRecognitionTask()
    }
    
    private func startRecognitionTask() {
        guard let speechRecognizer = speechRecognizer,
              let recognitionRequest = recognitionRequest else { return }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcriptionResult = self.processRecognitionResult(result)
                self.transcriptionSubject.send(transcriptionResult)
                
                // Update last speech time for silence detection
                if !result.bestTranscription.formattedString.isEmpty {
                    self.lastSpeechTime = Date()
                }
                
                if result.isFinal {
                    self.stopRecognition()
                }
            }
            
            if let error = error {
                self.handleRecognitionError(error)
            }
        }
    }
    
    private func processRecognitionResult(_ result: SFSpeechRecognitionResult) -> TranscriptionResult {
        let bestTranscription = result.bestTranscription
        
        // Extract segments with timing
        let segments = bestTranscription.segments.map { segment in
            TranscriptionSegment(
                substring: segment.substring,
                substringRange: segment.substringRange,
                timestamp: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence,
                alternativeSubstrings: segment.alternativeSubstrings
            )
        }
        
        // Build alternatives
        let alternatives = result.transcriptions.prefix(3).map { transcription in
            AlternativeTranscription(
                text: transcription.formattedString,
                confidence: transcription.confidence,
                likelihood: transcription.confidence // Using confidence as likelihood
            )
        }
        
        return TranscriptionResult(
            text: bestTranscription.formattedString,
            confidence: bestTranscription.confidence,
            segments: segments,
            alternatives: alternatives,
            isFinal: result.isFinal,
            timestamp: Date(),
            duration: TimeInterval(bestTranscription.segments.last?.timestamp ?? 0)
        )
    }
    
    private func processAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frames = buffer.frameLength
        var sum: Float = 0
        
        for i in 0..<Int(frames) {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frames)
        let level = Double(average) * 10
        
        DispatchQueue.main.async {
            self.audioLevel = min(level, 1.0)
        }
        
        // Silence detection
        detectSilence(audioLevel: 20 * log10(average))
    }
    
    private func detectSilence(audioLevel: Float) {
        if audioLevel < silenceLevel {
            let silenceDuration = Date().timeIntervalSince(lastSpeechTime)
            if silenceDuration >= silenceThreshold {
                silenceDetectionSubject.send(true)
                stopRecognition()
            }
        } else {
            lastSpeechTime = Date()
            silenceDetectionSubject.send(false)
        }
    }
    
    private func stopAudioEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
    }
    
    private func handleRecognitionError(_ error: Error) {
        let recognitionError: SpeechRecognitionError
        
        if let speechError = error as? SpeechRecognitionError {
            recognitionError = speechError
        } else {
            recognitionError = .generalError(error.localizedDescription)
        }
        
        transcriptionSubject.send(completion: .failure(recognitionError))
        stopRecognition()
    }
    
    private func configureSilenceDetection() {
        silenceThreshold = UserDefaults.standard.double(forKey: "silence_threshold")
        if silenceThreshold == 0 {
            silenceThreshold = 1.5 // Default
        }
    }
    
    private func setupAudioSession() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
    }
    
    private func stopSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    @objc private func audioSessionInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            stopRecognition()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Could resume if needed
                }
            }
        @unknown default:
            break
        }
    }
    
    @objc private func audioSessionRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable:
            // Handle microphone changes
            stopRecognition()
        default:
            break
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SpeechRecognitionManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if !available && self.isRecording {
                self.stopRecognition()
            }
        }
    }
}

// MARK: - Data Structures

struct TranscriptionResult {
    let text: String
    let confidence: Float
    let segments: [TranscriptionSegment]
    let alternatives: [AlternativeTranscription]
    let isFinal: Bool
    let timestamp: Date
    let duration: TimeInterval
}

struct TranscriptionSegment {
    let substring: String
    let substringRange: Range<String.Index>
    let timestamp: TimeInterval
    let duration: TimeInterval
    let confidence: Float
    let alternativeSubstrings: [String]
}

struct AlternativeTranscription {
    let text: String
    let confidence: Float
    let likelihood: Float
}

// MARK: - Errors

enum SpeechRecognitionError: Error, LocalizedError {
    case audioEngineFailure
    case recognizerUnavailable
    case noSpeechDetected
    case permissionDenied
    case generalError(String)
    
    var errorDescription: String? {
        switch self {
        case .audioEngineFailure:
            return "Audio engine failed to start"
        case .recognizerUnavailable:
            return "Speech recognizer is not available"
        case .noSpeechDetected:
            return "No speech was detected"
        case .permissionDenied:
            return "Microphone permission denied"
        case .generalError(let message):
            return message
        }
    }
}