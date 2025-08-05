import Foundation

enum RecordingState {
    case idle
    case recording
    case processing
    case playback
    case error(String)
}

enum TranslationError: Error, LocalizedError {
    case noInternet
    case speechRecognitionFailed
    case apiError(String)
    case rateLimited(timeRemaining: Int)
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "No Internet Connection"
        case .speechRecognitionFailed:
            return "Could Not Recognize Speech"
        case .apiError(let message):
            return "Translation Error: \(message)"
        case .rateLimited(let time):
            return "Too Many Requests - \(time)s remaining"
        case .serviceUnavailable:
            return "Translation Service Error"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noInternet:
            return "Check your connection and try again"
        case .speechRecognitionFailed:
            return "Please try speaking again or use text input instead"
        case .apiError:
            return "Please try again later"
        case .rateLimited:
            return "Please wait before trying again"
        case .serviceUnavailable:
            return "Service temporarily unavailable. Please try again later"
        }
    }
}

struct TranslationResult {
    let originalText: String
    let translatedText: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let timestamp: Date
    let confidence: Double?
    
    init(originalText: String, translatedText: String, sourceLanguage: Language, targetLanguage: Language, confidence: Double? = nil) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.timestamp = Date()
        self.confidence = confidence
    }
}