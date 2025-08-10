//
//  AudioConstants.swift
//  UniversalTranslator
//
//  Shared audio configuration constants for iPhone and Watch
//

import Foundation

struct AudioConstants {
    // Audio format settings
    static let sampleRate: Double = 44100.0
    static let numberOfChannels = 1
    static let bitRate = 128000
    
    // Recording limits
    static let maxRecordingDuration: TimeInterval = 30.0  // 30 seconds max for Watch
    static let maxChunkSize = 100000  // 100KB max for message transfer
    
    // File handling
    static func temporaryAudioFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "recording_\(UUID().uuidString).m4a"
        return tempDir.appendingPathComponent(fileName)
    }
    
    static func cleanupTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, 
                                                                   includingPropertiesForKeys: nil)
            for file in files where file.lastPathComponent.starts(with: "recording_") {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Failed to cleanup temporary files: \(error)")
        }
    }
}