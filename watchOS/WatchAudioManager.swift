//
//  WatchAudioManager.swift
//  UniversalTranslator Watch App
//
//  Handles audio recording and playback on the Watch
//

import Foundation
import AVFoundation
import WatchKit

class WatchAudioManager: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?  // Made internal so it can be accessed for volume control
    private var recordingURL: URL?
    private var currentAudioSession: AVAudioSession.Category = .playAndRecord
    
    @Published var isRecording = false
    @Published var isPlaying = false
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession(for category: AVAudioSession.Category = .playAndRecord) {
        let session = AVAudioSession.sharedInstance()
        do {
            // Only change category if it's different to avoid unnecessary interruptions
            if currentAudioSession != category {
                try session.setCategory(category, mode: .default, options: [.allowBluetooth, .defaultToSpeaker])
                currentAudioSession = category
            }
            
            if !session.isOtherAudioPlaying {
                try session.setActive(true)
            }
            
            print("✅ Audio session configured for: \(category)")
        } catch {
            print("❌ Failed to setup audio session for \(category): \(error)")
        }
    }
    
    // MARK: - Recording
    
    func startRecording(completion: @escaping (Bool) -> Void) {
        // Request permission first
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            DispatchQueue.main.async {
                self?.beginRecording(completion: completion)
            }
        }
    }
    
    private func beginRecording(completion: @escaping (Bool) -> Void) {
        // Clean up any previous recording and stop playback
        cleanupRecording()
        if isPlaying {
            stopPlayback()
        }
        
        // Create temporary file URL
        recordingURL = AudioConstants.temporaryAudioFileURL()
        
        // Configure recording settings optimized for Watch
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: AudioConstants.sampleRate,
            AVNumberOfChannelsKey: AudioConstants.numberOfChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: AudioConstants.bitRate
        ]
        
        do {
            // Setup audio session for recording
            setupAudioSession(for: .record)
            
            // Create and start recorder
            guard let url = recordingURL else {
                print("❌ Recording URL is nil")
                completion(false)
                return
            }
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // Set maximum duration
            let success = audioRecorder?.record(forDuration: AudioConstants.maxRecordingDuration) ?? false
            
            if success {
                isRecording = true
                completion(true)
                print("📹 Watch recording started: \(url.lastPathComponent)")
            } else {
                print("❌ Failed to start recording")
                isRecording = false
                completion(false)
            }
            
        } catch {
            print("❌ Failed to start recording: \(error)")
            isRecording = false
            completion(false)
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }
        
        audioRecorder?.stop()
        isRecording = false
        
        // Small delay to ensure recording is fully stopped
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify file exists and has content
            if let url = self.recordingURL,
               FileManager.default.fileExists(atPath: url.path) {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    print("📹 Watch recording saved: \(url.lastPathComponent), size: \(fileSize) bytes")
                    
                    if fileSize > 0 {
                        completion(url)
                    } else {
                        print("❌ Recording file is empty")
                        completion(nil)
                    }
                } catch {
                    print("❌ Failed to verify recording file: \(error)")
                    completion(nil)
                }
            } else {
                print("❌ Recording file not found")
                completion(nil)
            }
        }
    }
    
    // MARK: - Playback
    
    func playAudio(_ audioData: Data, volume: Float = 1.0, completion: @escaping (Bool) -> Void) {
        // Save data to temporary file
        let tempURL = AudioConstants.temporaryAudioFileURL()
        
        do {
            try audioData.write(to: tempURL)
            playAudioFromURL(tempURL, volume: volume, completion: completion)
        } catch {
            print("Failed to save audio data: \(error)")
            completion(false)
        }
    }
    
    func playAudioFromURL(_ url: URL, volume: Float = 1.0, completion: @escaping (Bool) -> Void) {
        // Stop any current playback
        if isPlaying {
            stopPlayback()
        }
        
        do {
            // Setup audio session for playback
            setupAudioSession(for: .playback)
            
            // Create and configure audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume  // Set volume before playing
            audioPlayer?.prepareToPlay()
            
            // Store completion for delegate callback
            playbackCompletion = completion
            
            // Start playback
            let success = audioPlayer?.play() ?? false
            
            if success {
                isPlaying = true
                print("🔊 Watch playing audio: \(url.lastPathComponent), duration: \(audioPlayer?.duration ?? 0)s, volume: \(volume)")
            } else {
                print("❌ Failed to start audio playback")
                isPlaying = false
                completion(false)
            }
            
        } catch {
            print("❌ Failed to play audio: \(error)")
            isPlaying = false
            completion(false)
        }
    }
    
    // Store completion handler for delegate callback
    private var playbackCompletion: ((Bool) -> Void)?
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackCompletion = nil
        
        // Deactivate audio session only if not recording
        if !isRecording {
            deactivateAudioSession()
        }
    }
    
    private func deactivateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            if !session.isOtherAudioPlaying {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            }
            print("✅ Audio session deactivated")
        } catch {
            print("⚠️ Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupRecording() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }
    
    deinit {
        cleanupRecording()
        AudioConstants.cleanupTemporaryFiles()
    }
}

// MARK: - AVAudioRecorderDelegate

extension WatchAudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("📹 Watch recording finished: \(flag ? "successfully" : "with error")")
        isRecording = false
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Watch recording error: \(error?.localizedDescription ?? "unknown")")
        isRecording = false
    }
}

// MARK: - AVAudioPlayerDelegate

extension WatchAudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🔊 Watch playback finished: \(flag ? "successfully" : "with error")")
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.audioPlayer = nil
            
            // Call completion handler
            self.playbackCompletion?(flag)
            self.playbackCompletion = nil
            
            // Deactivate audio session if not recording
            if !self.isRecording {
                self.deactivateAudioSession()
            }
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Watch playback error: \(error?.localizedDescription ?? "unknown")")
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.audioPlayer = nil
            
            // Call completion handler with error
            self.playbackCompletion?(false)
            self.playbackCompletion = nil
            
            // Deactivate audio session if not recording
            if !self.isRecording {
                self.deactivateAudioSession()
            }
        }
    }
}