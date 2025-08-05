import Foundation
import Combine

class TranslationService {
    static let shared = TranslationService()
    
    private let apiClient = GeminiAPIClient.shared
    private let speechRecognizer = SpeechRecognitionManager.shared
    private let audioService = AudioService.shared
    private let cache = TranslationCache.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // Publishers for real-time updates
    private let translationSubject = PassthroughSubject<TranslationResult, TranslationError>()
    var translationPublisher: AnyPublisher<TranslationResult, TranslationError> {
        translationSubject.eraseToAnyPublisher()
    }
    
    private init() {}
    
    func translate(text: String, from sourceLanguage: Language, to targetLanguage: Language) async throws -> TranslationResult {
        // Check cache first
        if let cachedResult = cache.retrieve(
            text: text,
            source: sourceLanguage.code,
            target: targetLanguage.code
        ) {
            let result = TranslationResult(
                originalText: text,
                translatedText: cachedResult.translated,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            translationSubject.send(result)
            return result
        }
        
        // Check network connectivity - with graceful degradation
        guard networkMonitor.isConnected else {
            // GRACEFUL DEGRADATION: Try to find similar cached translations
            if let fallbackResult = findSimilarCachedTranslation(text: text, targetLanguage: targetLanguage) {
                return fallbackResult
            }
            throw TranslationError.noInternet
        }
        
        // Validate text length
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.apiError("Empty text")
        }
        
        guard text.count <= 10000 else {
            throw TranslationError.textTooLong
        }
        
        // Create API request
        let request: TranslationRequest
        do {
            request = try TranslationRequest(
                textToTranslate: text,
                sourceLanguage: sourceLanguage.name,
                targetLanguage: targetLanguage.name
            )
        } catch {
            throw TranslationError.apiError("Failed to create translation request: \(error.localizedDescription)")
        }
        
        do {
            let response = try await apiClient.translate(request)
            
            guard let translatedText = response.translatedText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !translatedText.isEmpty else {
                throw TranslationError.apiError("No translation received")
            }
            
            let result = TranslationResult(
                originalText: text,
                translatedText: translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            
            // Cache the result
            cache.store(CachedTranslation(
                original: text,
                translated: translatedText,
                sourceLanguage: sourceLanguage.code,
                targetLanguage: targetLanguage.code,
                audioData: nil,
                timestamp: Date()
            ))
            
            // Publish result for real-time updates
            translationSubject.send(result)
            
            return result
            
        } catch {
            // GRACEFUL DEGRADATION: Try offline fallback before throwing
            if let fallbackResult = handleTranslationError(error, text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) {
                return fallbackResult
            }
            
            let translationError = mapAPIError(error)
            translationSubject.send(completion: .failure(translationError))
            throw translationError
        }
    }
    
    func detectLanguage(_ text: String) async throws -> String {
        guard networkMonitor.isConnected else {
            // GRACEFUL DEGRADATION: Use basic heuristics for common languages
            if let heuristicLanguage = detectLanguageHeuristically(text) {
                return heuristicLanguage
            }
            throw TranslationError.noInternet
        }
        
        do {
            let detectedCode = try await apiClient.detectLanguage(text)
            return detectedCode
        } catch {
            // GRACEFUL DEGRADATION: Fall back to heuristic detection
            if let heuristicLanguage = detectLanguageHeuristically(text) {
                return heuristicLanguage
            }
            throw mapAPIError(error)
        }
    }
    
    func getSupportedLanguages() -> [Language] {
        return Language.supportedLanguages
    }
    
    func validateLanguagePair(source: String, target: String) -> Bool {
        let supportedCodes = Language.supportedLanguages.map(\.code)
        return supportedCodes.contains(source) && supportedCodes.contains(target)
    }
    
    private func mapAPIError(_ error: Error) -> TranslationError {
        if let apiError = error as? APIError {
            switch apiError {
            case .noInternet:
                return .noInternet
            case .rateLimited(let retryAfter):
                return .rateLimited(timeRemaining: Int(retryAfter))
            case .invalidAPIKey:
                return .apiError("Invalid API key")
            case .serverError(let statusCode):
                return .apiError("Server error: \(statusCode)")
            case .serviceUnavailable:
                return .serviceUnavailable
            case .timeout:
                return .apiError("Request timeout")
            default:
                return .apiError(apiError.localizedDescription)
            }
        }
        
        return .apiError(error.localizedDescription)
    }
    
    // MARK: - Graceful Degradation Methods
    
    private func findSimilarCachedTranslation(text: String, targetLanguage: Language) -> TranslationResult? {
        // Try to find cached translations for similar text (partial matches)
        let supportedLanguages = Language.supportedLanguages
        
        for sourceLanguage in supportedLanguages {
            if let cached = cache.retrieve(text: text, source: sourceLanguage.code, target: targetLanguage.code) {
                return TranslationResult(
                    originalText: text,
                    translatedText: cached.translated,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            }
        }
        
        // Try fuzzy matching for similar phrases
        // This is a simplified implementation - in production you'd use more sophisticated matching
        let words = text.lowercased().components(separatedBy: .whitespaces)
        if words.count <= 3 {
            for sourceLanguage in supportedLanguages {
                if let cached = findCachedByKeywords(words: words, sourceLanguage: sourceLanguage.code, targetLanguage: targetLanguage.code) {
                    return TranslationResult(
                        originalText: text,
                        translatedText: "[Offline] \(cached.translated)",
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage
                    )
                }
            }
        }
        
        return nil
    }
    
    private func findCachedByKeywords(words: [String], sourceLanguage: String, targetLanguage: String) -> CachedTranslation? {
        // Simplified keyword-based cache lookup
        // In practice, this would use more sophisticated fuzzy matching
        for word in words {
            if let cached = cache.retrieve(text: word, source: sourceLanguage, target: targetLanguage) {
                return cached
            }
        }
        return nil
    }
    
    private func handleTranslationError(_ error: Error, text: String, sourceLanguage: Language, targetLanguage: Language) -> TranslationResult? {
        // Check if it's a rate limiting error - try cached fallback
        if let translationError = error as? TranslationError {
            switch translationError {
            case .rateLimited:
                // For rate limiting, try to find any cached translation
                return findSimilarCachedTranslation(text: text, targetLanguage: targetLanguage)
                
            case .noInternet, .serviceUnavailable:
                // For connectivity issues, provide offline alternatives
                if let offlineResult = provideOfflineAlternative(text: text, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage) {
                    return offlineResult
                }
                
            default:
                break
            }
        }
        
        return nil
    }
    
    private func provideOfflineAlternative(text: String, sourceLanguage: Language, targetLanguage: Language) -> TranslationResult? {
        // Provide basic offline translations for common phrases
        let basicTranslations: [String: [String: String]] = [
            "hello": ["en": "hello", "es": "hola", "fr": "bonjour", "de": "hallo"],
            "thank you": ["en": "thank you", "es": "gracias", "fr": "merci", "de": "danke"],
            "please": ["en": "please", "es": "por favor", "fr": "s'il vous plaît", "de": "bitte"],
            "yes": ["en": "yes", "es": "sí", "fr": "oui", "de": "ja"],
            "no": ["en": "no", "es": "no", "fr": "non", "de": "nein"],
            "excuse me": ["en": "excuse me", "es": "disculpe", "fr": "excusez-moi", "de": "entschuldigung"]
        ]
        
        let lowercasedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let translations = basicTranslations[lowercasedText],
           let translation = translations[targetLanguage.code] {
            return TranslationResult(
                originalText: text,
                translatedText: "[Offline] \(translation)",
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }
        
        return nil
    }
    
    private func detectLanguageHeuristically(_ text: String) -> String? {
        // Basic heuristic language detection using character patterns
        let cleanText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Spanish indicators
        if cleanText.contains("ñ") || cleanText.contains("¿") || cleanText.contains("¡") {
            return "es"
        }
        
        // French indicators
        if cleanText.contains("ç") || cleanText.contains("è") || cleanText.contains("é") || cleanText.contains("à") {
            return "fr"
        }
        
        // German indicators
        if cleanText.contains("ä") || cleanText.contains("ö") || cleanText.contains("ü") || cleanText.contains("ß") {
            return "de"
        }
        
        // Japanese indicators (Hiragana/Katakana)
        if cleanText.rangeOfCharacter(from: CharacterSet(charactersIn: "あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをん")) != nil ||
           cleanText.rangeOfCharacter(from: CharacterSet(charactersIn: "アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲン")) != nil {
            return "ja"
        }
        
        // Chinese indicators (simplified common characters)
        if cleanText.rangeOfCharacter(from: CharacterSet(charactersIn: "的是了我不人在他有这个上们来到时大地为子中你说生国年着就那和要她出也得里后自以会家可下而过天去能对小多然于心学么之都好看起发当没成只如事把还用第样道想作种开美总从无情己面最女但现前些所同日手又行意动方期它头经长儿回位分爱老因很给名法间斯知世什两次使身者被高已亲其进此话常与活正感")) != nil {
            return "zh"
        }
        
        // Default to English for Latin script
        if cleanText.rangeOfCharacter(from: CharacterSet.letters) != nil {
            return "en"
        }
        
        return nil
    }
}

// MARK: - Translation Cache

class TranslationCache {
    static let shared = TranslationCache()
    
    private let cache = NSCache<NSString, CachedTranslation>()
    private let maxMemoryItems = 100
    
    private init() {
        cache.countLimit = maxMemoryItems
    }
    
    func store(_ translation: CachedTranslation) {
        cache.setObject(translation, forKey: translation.cacheKey as NSString)
    }
    
    func retrieve(text: String, source: String, target: String) -> CachedTranslation? {
        let key = "\(source)_\(target)_\(text.hashValue)"
        
        if let cached = cache.object(forKey: key as NSString) {
            // Check if not expired (24 hours)
            if Date().timeIntervalSince(cached.timestamp) < 86400 {
                return cached
            }
        }
        
        return nil
    }
    
    func clearAll() {
        cache.removeAllObjects()
    }
}

class CachedTranslation: NSObject {
    let original: String
    let translated: String
    let sourceLanguage: String
    let targetLanguage: String
    let audioData: Data?
    let timestamp: Date
    
    var cacheKey: String {
        "\(sourceLanguage)_\(targetLanguage)_\(original.hashValue)"
    }
    
    init(original: String, translated: String, sourceLanguage: String, targetLanguage: String, audioData: Data?, timestamp: Date) {
        self.original = original
        self.translated = translated
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.audioData = audioData
        self.timestamp = timestamp
        super.init()
    }
}