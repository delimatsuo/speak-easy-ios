//
//  TranslationError.swift
//  UniversalTranslator
//
//  Shared error types for translation operations
//

import Foundation

enum TranslationError: LocalizedError {
    case recordingFailed
    case noAudioData
    case transcriptionFailed
    case translationFailed
    case networkError
    case noCredits
    case watchNotConnected
    case emptyText
    case invalidLanguage
    
    var errorDescription: String? {
        switch self {
        case .recordingFailed:
            return "Failed to record audio"
        case .noAudioData:
            return "No audio data available"
        case .transcriptionFailed:
            return "Failed to transcribe audio"
        case .translationFailed:
            return "Translation service unavailable"
        case .networkError:
            return "Network connection error"
        case .noCredits:
            return "No translation credits remaining"
        case .watchNotConnected:
            return "iPhone not reachable"
        case .emptyText:
            return "No text to translate"
        case .invalidLanguage:
            return "Invalid language selection"
        }
    }
}