import Foundation

enum TranslationError: Error {
    case networkTimeout
    case invalidLanguageCode(String)
    case translationFailed(String)
    case rateLimitExceeded(retryAfter: TimeInterval)
    case invalidAPIKey
    case serverError(statusCode: Int)
    case invalidResponse
    case textTooLong
}

enum TTSError: Error {
    case generationFailed(String)
    case unsupportedLanguage(String)
    case unsupportedVoice(String)
    case invalidAudioData
    case audioFormatConversionFailed
    case voiceNotAvailable
}

enum SpeechRecognitionError: Error {
    case audioEngineFailure
    case recognizerUnavailable
    case noSpeechDetected
    case permissionDenied
    case configurationFailed
}

enum KeychainError: Error {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedPasswordData
    case encryptionFailed
    case decryptionFailed
    case invalidKeyFormat
    case keyValidationFailed
}

enum QueueError: Error {
    case queueFull
    case taskNotFound
    case invalidTask
}

enum ConfigurationError: Error {
    case missingAPIBaseURL
    case invalidAPIBaseURL(String)
    case missingFirebaseConfig
    case invalidFirebaseConfig(String)
    case missingAPIKey
    case configurationValidationFailed([String])
}