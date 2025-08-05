import Foundation

class TranslationCache {
    static let shared = TranslationCache()
    
    private let cache = NSCache<NSString, CachedTranslation>()
    private let diskCache = DiskCacheManager(directory: "translations")
    private let maxMemoryItems = 100
    private let maxDiskSize = 50 * 1024 * 1024 // 50MB
    
    private init() {
        cache.countLimit = maxMemoryItems
        diskCache.setMaxSize(maxDiskSize)
    }
    
    func store(_ translation: CachedTranslation) {
        cache.setObject(translation, forKey: translation.cacheKey as NSString)
        
        Task {
            try? await diskCache.store(translation, key: translation.cacheKey)
        }
    }
    
    func retrieve(text: String, source: String, target: String) -> CachedTranslation? {
        let key = generateCacheKey(text: text, source: source, target: target)
        
        if let cached = cache.object(forKey: key as NSString) {
            if Date().timeIntervalSince(cached.timestamp) < 86400 { // 24 hours
                return cached
            } else {
                cache.removeObject(forKey: key as NSString)
            }
        }
        
        if let diskCached = try? Task { try await diskCache.retrieve(key: key, type: CachedTranslation.self) }.result.get() {
            if Date().timeIntervalSince(diskCached.timestamp) < 86400 {
                cache.setObject(diskCached, forKey: key as NSString)
                return diskCached
            }
        }
        
        return nil
    }
    
    func storeLanguageDetection(text: String, language: String) {
        let key = "lang_detect_\(text.hashValue)"
        let detection = LanguageDetection(text: text, detectedLanguage: language, timestamp: Date())
        
        UserDefaults.standard.set(language, forKey: key)
        UserDefaults.standard.set(Date(), forKey: "\(key)_timestamp")
    }
    
    func retrieveLanguageDetection(text: String) -> String? {
        let key = "lang_detect_\(text.hashValue)"
        
        guard let timestamp = UserDefaults.standard.object(forKey: "\(key)_timestamp") as? Date,
              Date().timeIntervalSince(timestamp) < 3600, // 1 hour
              let language = UserDefaults.standard.string(forKey: key) else {
            return nil
        }
        
        return language
    }
    
    func clearAll() {
        cache.removeAllObjects()
        
        Task {
            try? await diskCache.clear()
        }
        
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        
        for key in keys {
            if key.starts(with: "lang_detect_") {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    func preloadFrequentPairs() async {
        let frequentPairs = [
            ("en", "es"), ("en", "fr"), ("en", "de"),
            ("es", "en"), ("fr", "en"), ("de", "en")
        ]
        
        for (source, target) in frequentPairs {
            await loadCommonPhrases(source: source, target: target)
        }
    }
    
    func setPersistence(enabled: Bool) {
        if !enabled {
            clearAll()
        }
    }
    
    func getCacheStats() async -> CacheStats {
        let memoryCount = cache.description.components(separatedBy: "count = ").last?.components(separatedBy: ",").first
        let diskSize = await diskCache.getCurrentSize()
        
        return CacheStats(
            memoryItemCount: Int(memoryCount ?? "0") ?? 0,
            diskSizeBytes: diskSize,
            lastCleanup: Date()
        )
    }
    
    private func generateCacheKey(text: String, source: String, target: String) -> String {
        return "\(source)_\(target)_\(text.hashValue)"
    }
    
    private func loadCommonPhrases(source: String, target: String) async {
        let commonPhrases = [
            "Hello", "Thank you", "Please", "Excuse me", "How are you?",
            "Good morning", "Good evening", "Goodbye", "Yes", "No"
        ]
        
        for phrase in commonPhrases {
            if retrieve(text: phrase, source: source, target: target) == nil {
                print("Preloading phrase: \(phrase) (\(source) -> \(target))")
            }
        }
    }
}

class CachedTranslation: NSObject, Codable, Cacheable {
    let original: String
    let translated: String
    let sourceLanguage: String
    let targetLanguage: String
    let audioData: Data?
    let timestamp: Date
    
    var cacheKey: String {
        "\(sourceLanguage)_\(targetLanguage)_\(original.hashValue)"
    }
    
    var dataSize: Int {
        let textSize = original.utf8.count + translated.utf8.count
        let audioSize = audioData?.count ?? 0
        return textSize + audioSize + 100 // metadata overhead
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

struct LanguageDetection: Codable {
    let text: String
    let detectedLanguage: String
    let timestamp: Date
}

struct CacheStats {
    let memoryItemCount: Int
    let diskSizeBytes: Int
    let lastCleanup: Date
}