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
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    
    @Published var isRecording = false
    @Published var isPlaying = false
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
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
            // Activate audio session
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
            
            // Create and start recorder
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            
            // Set maximum duration
            audioRecorder?.record(forDuration: AudioConstants.maxRecordingDuration)
            
            isRecording = true
            completion(true)
            
            print("📹 Watch recording started: \(recordingURL!.lastPathComponent)")
            
        } catch {
            print("Failed to start recording: \(error)")
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
        
        // Deactivate audio session for recording
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        
        // Verify file exists and has content
        if let url = recordingURL,
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
                print("Failed to verify recording file: \(error)")
                completion(nil)
            }
        } else {
            print("❌ Recording file not found")
            completion(nil)
        }
    }
    
    // MARK: - Playback
    
    func playAudio(_ audioData: Data, completion: @escaping (Bool) -> Void) {
        // Save data to temporary file
        let tempURL = AudioConstants.temporaryAudioFileURL()
        
        do {
            try audioData.write(to: tempURL)
            playAudioFromURL(tempURL, completion: completion)
        } catch {
            print("Failed to save audio data: \(error)")
            completion(false)
        }
    }
    
    func playAudioFromURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        do {
            // Configure audio session for playback
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            
            // Create and play audio
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            isPlaying = true
            
            // Use completion handler after playback finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) {
                completion(true)
            }
            
            print("🔊 Watch playing audio: \(url.lastPathComponent)")
            
        } catch {
            print("Failed to play audio: \(error)")
            isPlaying = false
            completion(false)
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
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
        isPlaying = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ Watch playback error: \(error?.localizedDescription ?? "unknown")")
        isPlaying = false
    }
}