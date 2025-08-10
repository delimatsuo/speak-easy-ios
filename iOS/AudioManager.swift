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
        // Check microphone permission
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
    
    // New async version for better thread safety
    func startRecordingAsync() async -> Bool {
        return await withCheckedContinuation { continuation in
            startRecording { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    private func beginRecording() {
        do {
            // Setup audio session with better error handling
            let session = AVAudioSession.sharedInstance()
            
            // First check if audio input is available
            guard session.availableInputs?.isEmpty == false else {
                print("❌ No audio input available")
                isRecording = false
                return
            }
            
            // Set category with options that work better in production
            try session.setCategory(.playAndRecord, 
                                   mode: .measurement,  // Better for speech recording
                                   options: [.defaultToSpeaker, .allowBluetooth])
            
            // Activate session with options
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            
            print("✅ Audio session activated successfully")
            
            // Create recording URL
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
            recordingURL = documentsPath.appendingPathComponent(fileName)
            
            print("📁 Recording to: \(recordingURL!.lastPathComponent)")
            
            // Configure recorder settings for high quality
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128000
            ]
            
            // Create and start recorder
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // Actually start recording
            let recordingStarted = audioRecorder?.record() ?? false
            
            if recordingStarted {
                isRecording = true
                print("🎙️ Recording started successfully")
            } else {
                print("❌ Failed to start recording - recorder.record() returned false")
                isRecording = false
                // Clean up session
                try? session.setActive(false)
            }
            
        } catch let error as NSError {
            print("❌ Failed to start recording - Domain: \(error.domain), Code: \(error.code), Description: \(error.localizedDescription)")
            isRecording = false
            // Try to clean up audio session
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }
        
        audioRecorder?.stop()
        isRecording = false
        
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
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
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
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        resetTranscription()
    }
    
    private func resetTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    // MARK: - Playback
    
    func playAudio(_ audioData: Data, completion: @escaping (Bool) -> Void) {
        lastAudioData = audioData
        playbackCompletion = completion
        
        audioQueue.async {
            do {
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
            "hi": "hi-IN"
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