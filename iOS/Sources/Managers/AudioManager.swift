//
//  AudioManager.swift
//  UniversalTranslator
//
//  Handles audio recording, playback, and speech recognition
//

import Foundation
import AVFoundation
import Speech
import Firebase
import FirebaseStorage

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var transcribedText = ""
    
    var lastAudioData: Data?
    private var recordingURL: URL?
    
    // Thread safety
    private let audioQueue = DispatchQueue(label: "com.app.audio", qos: .userInitiated)
    private var playbackCompletion: ((Bool) -> Void)?
    
    override init() {
        super.init()
        setupSession()
    }
    
    // MARK: - Setup
    
    func setupSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Recording
    
    func startRecording(completion: @escaping (Bool) -> Void) {
        print("🔍 [RECORDING] startRecording called - Current state: isRecording=\(isRecording)")
        
        // Check if already recording
        if isRecording {
            print("⚠️ [RECORDING] Already recording - ignoring duplicate call")
            completion(false)
            return
        }
        
        // Check if audio recorder is still active from previous session
        if audioRecorder != nil {
            print("⚠️ [RECORDING] Previous audioRecorder still exists - cleaning up")
            audioRecorder?.stop()
            audioRecorder?.delegate = nil
            audioRecorder = nil
        }
        
        // Fast path: Check if permission is already granted
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission
        print("🔍 [RECORDING] Permission status: \(permissionStatus.rawValue)")
        
        if permissionStatus == .granted {
            // Permission already granted - start immediately
            print("🎙️ Permission already granted - starting recording immediately")
            self.beginRecording()
            completion(true)
        } else if permissionStatus == .denied {
            // Permission denied - fail fast
            print("❌ Recording permission denied")
            completion(false)
        } else {
            // Permission undetermined - request it
            print("🎙️ Requesting recording permission...")
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.beginRecording()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
        }
    }
    
    // New async version for better thread safety
    func startRecordingAsync() async -> Bool {
        return await withCheckedContinuation { continuation in
            startRecording { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    private func beginRecording() {
        print("🔍 [RECORDING] beginRecording called")
        
        // Update UI immediately for instant feedback
        DispatchQueue.main.async {
            self.isRecording = true
            print("🔍 [RECORDING] UI state updated: isRecording=true")
        }
        
        // Perform heavy operations on background queue
        audioQueue.async {
            do {
                let session = AVAudioSession.sharedInstance()
                print("🔍 [RECORDING] Audio session current state:")
                print("  - Category: \(session.category)")
                print("  - Mode: \(session.mode)")
                print("  - IsActive: \(session.isOtherAudioPlaying)")
                print("  - Available inputs: \(session.availableInputs?.count ?? 0)")
                
                // Quick availability check
                guard session.availableInputs?.isEmpty == false else {
                    print("❌ [RECORDING] No audio input available")
                    DispatchQueue.main.async { 
                        self.isRecording = false 
                        print("🔍 [RECORDING] UI state reset: isRecording=false (no input)")
                    }
                    return
                }
                
                // Ensure audio session is properly configured for recording
                print("🔍 [RECORDING] Configuring audio session for recording")
                try session.setCategory(.playAndRecord, 
                                       mode: .default,
                                       options: [.defaultToSpeaker, .allowBluetooth])
                print("🔍 [RECORDING] Audio session configured for recording")
                
                if !session.isOtherAudioPlaying {
                    print("🔍 [RECORDING] Activating audio session")
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                } else {
                    print("🔍 [RECORDING] Other audio playing - skipping activation")
                }
                
                print("✅ Audio session activated successfully")
                
                // Create recording URL
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
                self.recordingURL = documentsPath.appendingPathComponent(fileName)
                
                print("📁 Recording to: \(self.recordingURL!.lastPathComponent)")
                
                // Configure recorder settings for high quality
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                    AVEncoderBitRateKey: 128000
                ]
                
                // Create and start recorder
                self.audioRecorder = try AVAudioRecorder(url: self.recordingURL!, settings: settings)
                self.audioRecorder?.delegate = self
                self.audioRecorder?.isMeteringEnabled = true
                self.audioRecorder?.prepareToRecord()
                
                // Actually start recording
                let recordingStarted = self.audioRecorder?.record() ?? false
                
                DispatchQueue.main.async {
                    if recordingStarted {
                        print("🎙️ Recording started successfully")
                        // isRecording already set to true above
                    } else {
                        print("❌ Failed to start recording - recorder.record() returned false")
                        self.isRecording = false
                        // Clean up session
                        try? session.setActive(false)
                    }
                }
                
            } catch let error as NSError {
                print("❌ Failed to start recording - Domain: \(error.domain), Code: \(error.code), Description: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isRecording = false
                }
                // Try to clean up audio session
                try? AVAudioSession.sharedInstance().setActive(false)
            }
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        print("🔍 [RECORDING] stopRecording called - Current state: isRecording=\(isRecording)")
        
        guard isRecording else {
            print("⚠️ [RECORDING] stopRecording called but not recording - ignoring")
            completion(nil)
            return
        }
        
        print("🔍 [RECORDING] Stopping audio recorder...")
        audioRecorder?.stop()
        isRecording = false
        print("🔍 [RECORDING] UI state updated: isRecording=false")
        
        // Clean up audio recorder
        audioRecorder?.delegate = nil
        audioRecorder = nil
        print("🔍 [RECORDING] Audio recorder cleaned up")
        
        print("🛑 Recording stopped, session cleaned up")
        
        // Return the recording URL
        completion(recordingURL)
    }
    
    // MARK: - Speech Recognition
    
    func transcribeAudio(_ audioURL: URL, language: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            // Create recognizer for specified language
            let locale = Locale(identifier: languageToLocale(language))
            guard let recognizer = SFSpeechRecognizer(locale: locale) else {
                print("⚠️ No recognizer available for language: \(language) / locale: \(languageToLocale(language))")
                continuation.resume(throwing: TranscriptionError.recognizerNotAvailable)
                return
            }
            
            // Check if already authorized (don't request again)
            let currentStatus = SFSpeechRecognizer.authorizationStatus()
            guard currentStatus == .authorized else {
                print("⚠️ Speech recognition not authorized. Current status: \(currentStatus.rawValue)")
                continuation.resume(throwing: TranscriptionError.notAuthorized)
                return
            }
            
            // Check if recognizer is actually available
            guard recognizer.isAvailable else {
                print("⚠️ Speech recognizer reports not available for \(language)")
                continuation.resume(throwing: TranscriptionError.recognizerNotAvailable)
                return
            }
            
            // Create recognition request
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = false
            
            // Add timeout to prevent hanging
            var hasCompleted = false
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                if !hasCompleted {
                    hasCompleted = true
                    print("⏰ Speech recognition timed out after 10 seconds")
                    continuation.resume(throwing: TranscriptionError.recognizerNotAvailable)
                }
            }
            
            print("🎤 Starting speech recognition task for \(language)")
            
            // Perform recognition
            recognizer.recognitionTask(with: request) { result, error in
                guard !hasCompleted else { return }
                
                if let error = error {
                    hasCompleted = true
                    timeoutTimer.invalidate()
                    
                    // Check for kAFAssistantErrorDomain 1101
                    let nsError = error as NSError
                    print("❌ Speech recognition error - Domain: \(nsError.domain), Code: \(nsError.code), Description: \(error.localizedDescription)")
                    
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1101 {
                        print("⚠️ Speech recognition error 1101 - service temporarily unavailable")
                        continuation.resume(throwing: TranscriptionError.recognizerNotAvailable)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                if let result = result, result.isFinal {
                    hasCompleted = true
                    timeoutTimer.invalidate()
                    let transcription = result.bestTranscription.formattedString
                    print("✅ Speech recognition successful: \"\(transcription.prefix(50))...\"")
                    continuation.resume(returning: transcription)
                }
            }
        }
    }
    
    // MARK: - Live Transcription
    
    func startLiveTranscription(language: String) throws {
        // Reset previous session
        resetTranscription()
        
        // Configure recognizer
        let locale = Locale(identifier: languageToLocale(language))
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw TranscriptionError.recognizerNotAvailable
        }
        
        // Configure audio session for live transcription (measurement mode for better accuracy)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        
        // Set preferred sample rate to match what the hardware will provide
        try audioSession.setPreferredSampleRate(48000.0)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        print("🎵 Audio session configured - Sample rate: \(audioSession.sampleRate)Hz")
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Configure audio engine with hardware's exact format
        let inputNode = audioEngine.inputNode
        
        // Remove any existing tap first (removeTap doesn't throw)
        inputNode.removeTap(onBus: 0)
        print("🔧 Existing audio tap removed")
        
        // Use the hardware's exact native format to avoid any conversion
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("🎵 Using hardware format: \(recordingFormat)")
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start recognition
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
            
            if error != nil || (result?.isFinal ?? false) {
                self.stopLiveTranscription()
            }
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func stopLiveTranscription() {
        print("🔍 [TRANSCRIPTION] stopLiveTranscription called")
        
        // Clean up recognition components first
        print("🔍 [TRANSCRIPTION] Cleaning up recognition components...")
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // Stop audio engine with proper cleanup
        if audioEngine.isRunning {
            print("🔍 [TRANSCRIPTION] Stopping audio engine...")
            audioEngine.stop()
        } else {
            print("🔍 [TRANSCRIPTION] Audio engine already stopped")
        }
        
        // Remove tap and reset input node (safely)
        print("🔍 [TRANSCRIPTION] Removing audio engine tap...")
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        print("🔧 Audio engine tap removed successfully")
        
        // Reset audio engine completely for next use
        print("🔍 [TRANSCRIPTION] Resetting audio engine...")
        audioEngine.reset()
        
        resetTranscription()
        
        // CRITICAL FIX: Properly reset audio session for next recording
        print("🔍 [TRANSCRIPTION] Resetting audio session for next recording...")
        do {
            let session = AVAudioSession.sharedInstance()
            print("🔍 [TRANSCRIPTION] Current session state:")
            print("  - Category: \(session.category)")
            print("  - Mode: \(session.mode)")
            print("  - Sample rate: \(session.sampleRate)Hz")
            print("  - IsActive: \(session.isOtherAudioPlaying)")
            
            // CRITICAL: Reset session completely to avoid conflicts
            // First deactivate to clear any lingering state
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            print("🔍 [TRANSCRIPTION] Session deactivated")
            
            // Wait a brief moment for the session to fully reset
            Thread.sleep(forTimeInterval: 0.1)
            
            // Reconfigure for recording with default mode (not measurement)
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            print("🔍 [TRANSCRIPTION] Session reconfigured for recording")
            
            // Reactivate the session
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ Audio session reset and ready for next recording - Sample rate: \(session.sampleRate)Hz")
            
        } catch {
            print("⚠️ [TRANSCRIPTION] Failed to reset audio session: \(error)")
        }
    }
    
    private func resetTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Clear transcribed text for fresh start
        DispatchQueue.main.async {
            self.transcribedText = ""
        }
    }
    
    // MARK: - Lifecycle Management
    
    func forceCleanupAllSessions() {
        print("🧹 Force cleanup all audio sessions (auth change)")
        
        // Stop any active recording
        if isRecording {
            audioRecorder?.stop()
            audioRecorder?.delegate = nil
            audioRecorder = nil
            isRecording = false
        }
        
        // Stop any active playback
        if isPlaying {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlaying = false
        }
        
        // Stop live transcription
        stopLiveTranscription()
        
        // Reset audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session deactivated for auth change")
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - Playback
    
    func playAudio(_ audioData: Data, completion: @escaping (Bool) -> Void) {
        lastAudioData = audioData
        playbackCompletion = completion
        
        audioQueue.async {
            do {
                // CRITICAL FIX: Configure audio session for playback with loudspeaker
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                
                print("🔊 Audio session configured for LOUDSPEAKER playback")
                
                // Create player from data
                self.audioPlayer = try AVAudioPlayer(data: audioData)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                
                DispatchQueue.main.async {
                    self.isPlaying = true
                    self.audioPlayer?.play()
                }
            } catch {
                print("Failed to play audio: \(error)")
                DispatchQueue.main.async {
                    self.isPlaying = false
                    completion(false)
                }
            }
        }
    }
    
    // New async version for better thread safety
    func playAudioAsync(_ audioData: Data) async -> Bool {
        return await withCheckedContinuation { continuation in
            playAudio(audioData) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    func playAudioFromURL(_ url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to play audio from URL: \(error)")
            isPlaying = false
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
    }
    
    // MARK: - Audio Processing
    
    func saveAudioToFirebase(_ audioData: Data, completion: @escaping (String?) -> Void) {
        let storage = Storage.storage()
        let storageRef = storage.reference()
        let fileName = "audio_\(Date().timeIntervalSince1970).m4a"
        let audioRef = storageRef.child("translations/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "audio/m4a"
        
        audioRef.putData(audioData, metadata: metadata) { metadata, error in
            if let error = error {
                print("Failed to upload audio: \(error)")
                completion(nil)
                return
            }
            
            audioRef.downloadURL { url, error in
                completion(url?.absoluteString)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func languageToLocale(_ languageCode: String) -> String {
        let localeMap: [String: String] = [
            // Original languages - ONLY GEMINI 2.5 FLASH TTS SUPPORTED
            "en": "en-US",
            "es": "es-ES",
            "fr": "fr-FR",
            "de": "de-DE",
            "it": "it-IT",
            "pt": "pt-BR",
            "ru": "ru-RU",
            "ja": "ja-JP",
            "ko": "ko-KR",
            "zh": "zh-CN",
            "ar": "ar-SA",
            "hi": "hi-IN",
            
            // Phase 1: Major Market Languages
            "id": "id-ID",
            // REMOVED: Filipino (fil) - Not supported by Gemini 2.5 Flash TTS
            "vi": "vi-VN",
            "tr": "tr-TR",
            "th": "th-TH",
            "pl": "pl-PL",
            
            // Phase 2: Regional Powerhouses
            "bn": "bn-BD",
            "te": "te-IN",
            "mr": "mr-IN",
            "ta": "ta-IN",
            "uk": "uk-UA",
            "ro": "ro-RO"
        ]
        return localeMap[languageCode] ?? "en-US"
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            // Call completion handler if available
            self.playbackCompletion?(flag)
            self.playbackCompletion = nil
        }
    }
}

// MARK: - Errors

enum TranscriptionError: LocalizedError {
    case recognizerNotAvailable
    case notAuthorized
    case requestCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .recognizerNotAvailable:
            return "Speech recognizer is not available for this language"
        case .notAuthorized:
            return "Speech recognition is not authorized"
        case .requestCreationFailed:
            return "Failed to create recognition request"
        }
    }
}