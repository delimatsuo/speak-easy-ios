//
//  AudioConstants.swift
//  UniversalTranslator
//
//  Shared audio configuration constants
//

import Foundation

struct AudioConstants {
    // Recording settings
    static let sampleRate = 44100.0
    static let numberOfChannels = 1
    static let bitRate = 64000  // Lower for Watch
    static let maxRecordingDuration: TimeInterval = 30.0
    
    // File formats
    static let audioFileExtension = "m4a"
    static let audioFormat = "kAudioFormatMPEG4AAC"
    
    // WatchConnectivity
    static let maxChunkSize = 100_000  // 100KB chunks
    static let transferTimeout: TimeInterval = 30.0
    
    // Temporary file management
    static func temporaryAudioFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "watch_audio_\(Date().timeIntervalSince1970).\(audioFileExtension)"
        return tempDir.appendingPathComponent(fileName)
    }
    
    static func cleanupTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == audioFileExtension {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Failed to cleanup temporary files: \(error)")
        }
    }
}