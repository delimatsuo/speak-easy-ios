import Foundation
import AVFoundation

class GeminiTTSService: TTSService {
    private let apiClient: GeminiAPIClient
    private let errorHandler: TTSErrorHandler
    private let cache: TTSCache
    
    init() {
        self.apiClient = GeminiAPIClient.shared
        self.errorHandler = TTSErrorHandler()
        self.cache = TTSCache.shared
    }
    
    func synthesize(text: String, language: String, voice: VoiceParameters?) async throws -> Data {
        let preparedText = preprocessText(text)
        
        guard !preparedText.isEmpty else {
            throw TTSError.generationFailed("Empty text provided")
        }
        
        guard preparedText.count <= 5000 else {
            throw TTSError.generationFailed("Text too long for TTS (max 5000 characters)")
        }
        
        let voiceParams = voice ?? VoiceParameters.default
        let cacheKey = generateCacheKey(text: preparedText, language: language, voice: voiceParams)
        
        if let cachedAudio = cache.retrieve(key: cacheKey) {
            return cachedAudio
        }
        
        let languageCode = LanguageCodeMapper.getBCP47Code(for: language) ?? language
        
        let request = TTSRequest(
            text: preparedText,
            languageCode: languageCode,
            voiceParams: voiceParams
        )
        
        do {
            let response = try await apiClient.synthesizeSpeech(request)
            let audioData = try response.decodeAudio()
            
            let processedAudio = try processAudioData(audioData, parameters: voiceParams)
            
            cache.store(processedAudio, key: cacheKey)
            
            return processedAudio
            
        } catch {
            return try await errorHandler.handle(error, request: request, service: self)
        }
    }
    
    func getAvailableVoices(for language: String) -> [Voice] {
        return VoiceSelector.getAvailableVoices(for: language)
    }
    
    func preloadVoice(_ voice: Voice) async throws {
        let testText = getTestPhrase(for: voice.languageCode)
        let voiceParams = VoiceParameters(
            gender: voice.gender,
            speakingRate: 1.0,
            pitch: 0.0,
            volumeGainDb: 0.0
        )
        
        _ = try await synthesize(text: testText, language: voice.languageCode, voice: voiceParams)
    }
    
    func synthesizeBatch(texts: [String], language: String, voice: VoiceParameters?) async throws -> [Data] {
        return try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask {
                    let audioData = try await self.synthesize(text: text, language: language, voice: voice)
                    return (index, audioData)
                }
            }
            
            var results: [(Int, Data)] = []
            for try await result in group {
                results.append(result)
            }
            
            results.sort { $0.0 < $1.0 }
            return results.map { $0.1 }
        }
    }
    
    func estimateAudioDuration(text: String, voice: VoiceParameters?) -> TimeInterval {
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).count
        let baseWordsPerMinute: Double = 150
        
        let speakingRate = Double(voice?.speakingRate ?? 1.0)
        let adjustedWordsPerMinute = baseWordsPerMinute * speakingRate
        
        let durationInMinutes = Double(wordCount) / adjustedWordsPerMinute
        return durationInMinutes * 60
    }
    
    private func preprocessText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let normalized = trimmed.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        let cleaned = normalized.replacingOccurrences(
            of: "[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]",
            with: "",
            options: .regularExpression
        )
        
        return cleaned
    }
    
    private func generateCacheKey(text: String, language: String, voice: VoiceParameters) -> String {
        let voiceString = "\(voice.gender.rawValue)_\(voice.speakingRate)_\(voice.pitch)_\(voice.volumeGainDb)"
        let combined = "\(language)_\(voiceString)_\(text)"
        return String(combined.hashValue)
    }
    
    private func processAudioData(_ data: Data, parameters: VoiceParameters) throws -> Data {
        guard let audioFile = try? AVAudioFile(forReading: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_audio.mp3")) else {
            return data
        }
        
        return data
    }
    
    private func getTestPhrase(for languageCode: String) -> String {
        let language = String(languageCode.prefix(2)).lowercased()
        
        let testPhrases: [String: String] = [
            "en": "Hello, this is a test.",
            "es": "Hola, esto es una prueba.",
            "fr": "Bonjour, ceci est un test.",
            "de": "Hallo, das ist ein Test.",
            "ja": "こんにちは、これはテストです。",
            "zh": "你好，这是一个测试。",
            "ko": "안녕하세요, 이것은 테스트입니다.",
            "it": "Ciao, questo è un test.",
            "pt": "Olá, este é um teste.",
            "ru": "Привет, это тест.",
            "ar": "مرحبا، هذا اختبار.",
            "hi": "नमस्ते, यह एक परीक्षण है।",
            "nl": "Hallo, dit is een test.",
            "sv": "Hej, det här är ett test.",
            "pl": "Cześć, to jest test."
        ]
        
        return testPhrases[language] ?? "Hello, this is a test."
    }
}

class TTSErrorHandler {
    private let backoff = ExponentialBackoff()
    
    func handle(_ error: Error, request: TTSRequest, service: GeminiTTSService) async throws -> Data {
        switch error {
        case TTSError.unsupportedLanguage(let language):
            return try await handleUnsupportedLanguage(language, request: request, service: service)
            
        case TTSError.unsupportedVoice:
            return try await handleUnsupportedVoice(request, service: service)
            
        case TTSError.generationFailed:
            return try await handleGenerationFailed(request, service: service)
            
        case TTSError.audioFormatConversionFailed:
            return try await handleFormatConversionFailed(request, service: service)
            
        case TranslationError.rateLimitExceeded(let retryAfter):
            try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
            return try await retryTTS(request, service: service)
            
        case TranslationError.networkTimeout:
            guard let delay = backoff.nextDelay() else {
                throw error
            }
            
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await retryTTS(request, service: service)
            
        default:
            throw error
        }
    }
    
    private func handleUnsupportedLanguage(_ language: String, request: TTSRequest, service: GeminiTTSService) async throws -> Data {
        var modifiedRequest = request
        modifiedRequest.voice.languageCode = "en-US"
        
        return try await retryTTS(modifiedRequest, service: service)
    }
    
    private func handleUnsupportedVoice(_ request: TTSRequest, service: GeminiTTSService) async throws -> Data {
        var modifiedRequest = request
        modifiedRequest.voice.name = nil
        
        return try await retryTTS(modifiedRequest, service: service)
    }
    
    private func handleGenerationFailed(_ request: TTSRequest, service: GeminiTTSService) async throws -> Data {
        let simplifiedText = simplifyText(request.input.text)
        
        var modifiedRequest = request
        modifiedRequest.input.text = simplifiedText
        
        return try await retryTTS(modifiedRequest, service: service)
    }
    
    private func handleFormatConversionFailed(_ request: TTSRequest, service: GeminiTTSService) async throws -> Data {
        var modifiedRequest = request
        modifiedRequest.audioConfig.audioEncoding = "LINEAR16"
        
        return try await retryTTS(modifiedRequest, service: service)
    }
    
    private func retryTTS(_ request: TTSRequest, service: GeminiTTSService) async throws -> Data {
        let response = try await GeminiAPIClient.shared.synthesizeSpeech(request)
        return try response.decodeAudio()
    }
    
    private func simplifyText(_ text: String) -> String {
        let simplified = text.replacingOccurrences(
            of: "[^a-zA-Z0-9\\s.,!?]",
            with: "",
            options: .regularExpression
        )
        return simplified.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

class TTSCache {
    static let shared = TTSCache()
    
    private let cache = NSCache<NSString, NSData>()
    private let diskCache: DiskCache
    private let maxMemoryItems = 50
    private let maxDiskSize = 100 * 1024 * 1024
    
    private init() {
        self.diskCache = DiskCache(directory: "tts_cache", maxSize: maxDiskSize)
        cache.countLimit = maxMemoryItems
    }
    
    func store(_ audioData: Data, key: String) {
        cache.setObject(audioData as NSData, forKey: key as NSString)
        
        Task {
            try? await diskCache.store(audioData, key: key)
        }
    }
    
    func retrieve(key: String) -> Data? {
        if let cached = cache.object(forKey: key as NSString) {
            return cached as Data
        }
        
        return try? diskCache.retrieve(key: key)
    }
    
    func clear() {
        cache.removeAllObjects()
        try? diskCache.clear()
    }
    
    func getSize() -> Int {
        return diskCache.getCurrentSize()
    }
}

class DiskCache {
    private let directory: URL
    private let maxSize: Int
    
    init(directory: String, maxSize: Int) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.directory = documentsPath.appendingPathComponent(directory)
        self.maxSize = maxSize
        
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }
    
    func store(_ data: Data, key: String) async throws {
        let url = directory.appendingPathComponent(key)
        try data.write(to: url)
        
        try await cleanupIfNeeded()
    }
    
    func retrieve(key: String) throws -> Data {
        let url = directory.appendingPathComponent(key)
        return try Data(contentsOf: url)
    }
    
    func clear() throws {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in files {
            try FileManager.default.removeItem(at: file)
        }
    }
    
    func getCurrentSize() -> Int {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += fileSize
            }
        }
        
        return totalSize
    }
    
    private func cleanupIfNeeded() async throws {
        let currentSize = getCurrentSize()
        
        if currentSize > maxSize {
            let files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey]
            )
            
            let sortedFiles = files.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 < date2
            }
            
            var sizeToDelete = currentSize - (maxSize * 3 / 4)
            
            for file in sortedFiles {
                if sizeToDelete <= 0 { break }
                
                if let resourceValues = try? file.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    try FileManager.default.removeItem(at: file)
                    sizeToDelete -= fileSize
                }
            }
        }
    }
}