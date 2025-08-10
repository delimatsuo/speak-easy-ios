//
//  TranslationError.swift
//  UniversalTranslator
//
//  Shared error types for translation operations
//

import Foundation

enum TranslationError: LocalizedError {
    // Core errors
    case emptyText
    case invalidResponse
    case invalidURL
    case httpError(Int)
    case apiError(String)
    case networkError
    case timeout
    case audioDownloadFailed
    case cancelled
    
    // Watch-specific errors
    case recordingFailed
    case noAudioData
    case transcriptionFailed
    case translationFailed
    case noCredits
    case watchNotConnected
    case invalidLanguage
    
    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Please speak something to translate"
        case .invalidResponse:
            return "Invalid response from translation server"
        case .invalidURL:
            return "Invalid audio URL provided by server"
        case .httpError(let code):
            switch code {
            case 400:
                return "Bad request - please check your input"
            case 401:
                return "Authentication failed - please check API key"
            case 403:
                return "Access forbidden - API key may be invalid"
            case 404:
                return "Translation service not found"
            case 429:
                return "Too many requests - please wait and try again"
            case 500:
                return "Server error - please try again later"
            case 503:
                return "Service unavailable - please try again later"
            default:
                return "HTTP error: \(code)"
            }
        case .apiError(let message):
            return message
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .timeout:
            return "Request timed out. Please try again."
        case .audioDownloadFailed:
            return "Failed to download translation audio"
        case .cancelled:
            return "Request was cancelled"
        case .recordingFailed:
            return "Failed to record audio"
        case .noAudioData:
            return "No audio data available"
        case .transcriptionFailed:
            return "Failed to transcribe audio"
        case .translationFailed:
            return "Translation service unavailable"
        case .noCredits:
            return "No translation credits remaining"
        case .watchNotConnected:
            return "iPhone not reachable"
        case .invalidLanguage:
            return "Invalid language selection"
        }
    }
}