import Foundation

class GeminiTranslationService: TranslationService {
    private let apiClient: GeminiAPIClient
    private let errorHandler: TranslationErrorHandler
    private let cache: TranslationCache
    
    init() {
        self.apiClient = GeminiAPIClient.shared
        self.errorHandler = TranslationErrorHandler()
        self.cache = TranslationCache.shared
    }
    
    func translate(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> Translation {
        let preparedText = preprocessText(text)
        
        guard !preparedText.isEmpty else {
            throw TranslationError.translationFailed("Empty text provided")
        }
        
        guard validateLanguagePair(source: sourceLanguage, target: targetLanguage) else {
            throw TranslationError.invalidLanguageCode("Unsupported language pair: \(sourceLanguage) -> \(targetLanguage)")
        }
        
        if let cachedTranslation = cache.retrieve(text: preparedText, source: sourceLanguage, target: targetLanguage) {
            return Translation(
                originalText: preparedText,
                translatedText: cachedTranslation.translated,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                confidence: 0.95,
                timestamp: Date()
            )
        }
        
        let request: TranslationRequest
        do {
            request = try TranslationRequest(
                textToTranslate: preparedText,
                sourceLanguage: getLanguageName(for: sourceLanguage),
                targetLanguage: getLanguageName(for: targetLanguage)
            )
        } catch {
            throw error
        }
        
        do {
            let response = try await apiClient.translate(request)
            
            guard let translatedText = response.translatedText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !translatedText.isEmpty else {
                throw TranslationError.translationFailed("Empty translation response")
            }
            
            let translation = Translation(
                originalText: preparedText,
                translatedText: translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                confidence: calculateConfidence(from: response),
                timestamp: Date()
            )
            
            cache.store(CachedTranslation(
                original: preparedText,
                translated: translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                audioData: nil,
                timestamp: Date()
            ))
            
            return translation
            
        } catch {
            return try await errorHandler.handle(error, request: request, service: self)
        }
    }
    
    func detectLanguage(text: String) async throws -> String {
        let preparedText = preprocessText(text)
        
        guard !preparedText.isEmpty else {
            throw TranslationError.translationFailed("Empty text provided for language detection")
        }
        
        if let cachedDetection = cache.retrieveLanguageDetection(text: preparedText) {
            return cachedDetection
        }
        
        let detectedLanguage = try await apiClient.detectLanguage(preparedText)
        
        guard LanguageCodeMapper.validate(detectedLanguage) else {
            throw TranslationError.invalidLanguageCode("Detected invalid language code: \(detectedLanguage)")
        }
        
        cache.storeLanguageDetection(text: preparedText, language: detectedLanguage)
        
        return detectedLanguage
    }
    
    func getSupportedLanguages() -> [Language] {
        return LanguageCodeMapper.getAllSupportedLanguages()
    }
    
    func validateLanguagePair(source: String, target: String) -> Bool {
        guard source != target else { return false }
        return LanguageCodeMapper.validatePair(source: source, target: target)
    }
    
    private func preprocessText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let normalized = trimmed.precomposedStringWithCanonicalMapping
        
        let filtered = normalized.replacingOccurrences(
            of: "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]",
            with: "",
            options: .regularExpression
        )
        
        return filtered
    }
    
    private func getLanguageName(for code: String) -> String {
        return LanguageCodeMapper.getLanguageInfo(for: code)?.name ?? code
    }
    
    private func calculateConfidence(from response: TranslationResponse) -> Float {
        let hasMultipleCandidates = response.candidates.count > 1
        let tokenCount = response.usageMetadata.promptTokenCount
        
        var confidence: Float = 0.85
        
        if hasMultipleCandidates {
            confidence += 0.05
        }
        
        if tokenCount < 100 {
            confidence += 0.05
        } else if tokenCount > 500 {
            confidence -= 0.05
        }
        
        return min(max(confidence, 0.0), 1.0)
    }
}

class TranslationErrorHandler {
    private let backoff = ExponentialBackoff()
    
    func handle(_ error: Error, request: TranslationRequest, service: GeminiTranslationService) async throws -> Translation {
        switch error {
        case TranslationError.networkTimeout:
            guard let delay = backoff.nextDelay() else {
                throw error
            }
            
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await retryTranslation(request, service: service)
            
        case TranslationError.rateLimitExceeded(let retryAfter):
            try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
            return try await retryTranslation(request, service: service)
            
        case TranslationError.invalidLanguageCode(let code):
            return try await handleInvalidLanguageCode(code, request: request, service: service)
            
        case TranslationError.translationFailed:
            return try await retryWithAlternativePrompt(request, service: service)
            
        case TranslationError.serverError(let statusCode) where statusCode >= 500:
            guard let delay = backoff.nextDelay() else {
                throw error
            }
            
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await retryTranslation(request, service: service)
            
        default:
            throw error
        }
    }
    
    private func retryTranslation(_ request: TranslationRequest, service: GeminiTranslationService) async throws -> Translation {
        let response = try await GeminiAPIClient.shared.translate(request)
        
        guard let translatedText = response.translatedText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !translatedText.isEmpty else {
            throw TranslationError.translationFailed("Empty translation response on retry")
        }
        
        return Translation(
            originalText: request.contents.first?.parts.first?.text ?? "",
            translatedText: translatedText,
            sourceLanguage: "auto",
            targetLanguage: "en",
            confidence: 0.75,
            timestamp: Date()
        )
    }
    
    private func handleInvalidLanguageCode(_ code: String, request: TranslationRequest, service: GeminiTranslationService) async throws -> Translation {
        guard let originalText = request.contents.first?.parts.first?.text else {
            throw TranslationError.translationFailed("Cannot extract original text")
        }
        
        let fallbackRequest: TranslationRequest
        do {
            fallbackRequest = try TranslationRequest(
                textToTranslate: originalText,
                sourceLanguage: "auto",
                targetLanguage: "English"
            )
        } catch {
            throw TranslationError.translationFailed("Failed to create fallback request: \(error.localizedDescription)")
        }
        
        return try await retryTranslation(fallbackRequest, service: service)
    }
    
    private func retryWithAlternativePrompt(_ request: TranslationRequest, service: GeminiTranslationService) async throws -> Translation {
        guard let originalText = request.contents.first?.parts.first?.text else {
            throw TranslationError.translationFailed("Cannot extract original text")
        }
        
        let alternativeRequest: TranslationRequest
        do {
            alternativeRequest = try TranslationRequest(
                textToTranslate: originalText,
                sourceLanguage: "the source language",
                targetLanguage: "English"
            )
        } catch {
            throw TranslationError.translationFailed("Failed to create alternative request: \(error.localizedDescription)")
        }
        
        return try await retryTranslation(alternativeRequest, service: service)
    }
}