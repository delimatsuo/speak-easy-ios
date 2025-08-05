//
//  NetworkConfig.swift
//  UniversalTranslator
//
//  Network configuration for voice translation API
//

import Foundation

struct NetworkConfig {
    // Your Cloud Run API base URL
    static let apiBaseURL = "https://universal-translator-api-932729595834.us-central1.run.app"
    
    // API Endpoints
    enum Endpoint {
        static let health = "/health"
        static let translate = "/v1/translate"
        static let translateAudio = "/v1/translate/audio"  // New endpoint for audio
        static let languages = "/v1/languages"
        static let speechToText = "/v1/speech-to-text"
        static let textToSpeech = "/v1/text-to-speech"
    }
    
    // Request timeout
    static let requestTimeout: TimeInterval = 60.0  // Increased for audio processing
    
    // Audio settings
    static let maxRecordingDuration: TimeInterval = 60.0
    static let audioSampleRate = 44100.0
    static let audioBitRate = 128000
}

// MARK: - Voice Models

enum VoiceGender: String, Codable {
    case male = "male"
    case female = "female" 
    case neutral = "neutral"
}

enum AudioFormat: String, Codable {
    case mp3 = "mp3"
    case m4a = "m4a"
    case wav = "wav"
}