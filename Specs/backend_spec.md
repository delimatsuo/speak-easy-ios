# Backend Specification - iPhone Universal Translator App

## 1. On-Device Speech-to-Text (STT)

### 1.1 Apple Speech Framework Integration

#### Core Components
```swift
import Speech
import AVFoundation

class SpeechRecognitionManager: NSObject {
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Configuration
    var silenceThreshold: TimeInterval = 1.5 // Configurable 0.5-2.0 seconds
    var enablePartialResults = true
    var requiresOnDeviceRecognition = false
}
```

#### Initialization & Configuration
```swift
struct SpeechRecognitionConfig {
    let locale: Locale                    // Language locale (e.g., en-US)
    let shouldReportPartialResults: Bool  // Live transcription
    let requiresOnDeviceRecognition: Bool // Privacy mode
    let contextualStrings: [String]       // Domain-specific terms
    let interactionIdentifier: String?    // Analytics tracking
}
```

### 1.2 Output Format Specification

#### Primary Output Structure
```swift
struct TranscriptionResult {
    let text: String                      // UTF-8 encoded transcribed text
    let confidence: Float                 // Overall confidence (0.0-1.0)
    let segments: [TranscriptionSegment]  // Word-level details
    let alternatives: [AlternativeTranscription] // Alternative interpretations
    let isFinal: Bool                     // Final vs partial result
    let timestamp: Date                   // Recognition timestamp
    let duration: TimeInterval            // Audio duration
}

struct TranscriptionSegment {
    let substring: String                 // Word or phrase
    let substringRange: Range<String.Index> // Position in full text
    let timestamp: TimeInterval           // Start time in audio
    let duration: TimeInterval            // Word duration
    let confidence: Float                 // Word-level confidence (0.0-1.0)
    let alternativeSubstrings: [String]   // Alternative words
}

struct AlternativeTranscription {
    let text: String
    let confidence: Float
    let likelihood: Float                 // Relative probability
}
```

#### JSON Output Format
```json
{
    "transcription": {
        "text": "Hello, how are you today",
        "confidence": 0.95,
        "is_final": true,
        "timestamp": "2025-08-03T10:30:45.123Z",
        "duration": 2.5,
        "segments": [
            {
                "text": "Hello",
                "start_time": 0.0,
                "duration": 0.4,
                "confidence": 0.98,
                "alternatives": ["Hello", "Hallo", "Yellow"]
            },
            {
                "text": "how",
                "start_time": 0.5,
                "duration": 0.2,
                "confidence": 0.97,
                "alternatives": ["how", "now"]
            }
        ],
        "alternatives": [
            {
                "text": "Hello, how are you today",
                "confidence": 0.95,
                "likelihood": 0.85
            },
            {
                "text": "Hello, who are you today",
                "confidence": 0.88,
                "likelihood": 0.12
            }
        ]
    }
}
```

### 1.3 Speech Recognition Requirements

#### Silence Detection
```swift
class SilenceDetector {
    private var silenceTimer: Timer?
    private var silenceThreshold: TimeInterval = 1.5
    private var lastSpeechTime: Date = Date()
    
    func configureSilenceDetection() {
        // Configurable threshold range: 0.5 - 2.0 seconds
        silenceThreshold = UserDefaults.standard.double(
            forKey: "silence_threshold",
            default: 1.5
        )
    }
    
    func detectSilence(audioLevel: Float) -> Bool {
        let silenceLevel: Float = -50.0 // dB threshold
        if audioLevel < silenceLevel {
            let silenceDuration = Date().timeIntervalSince(lastSpeechTime)
            return silenceDuration >= silenceThreshold
        } else {
            lastSpeechTime = Date()
            return false
        }
    }
}
```

#### Background Noise Filtering
```swift
class AudioProcessor {
    private let audioEngine = AVAudioEngine()
    private var noiseSuppressionNode: AVAudioUnitEQ?
    
    func configureNoiseReduction() {
        // Configure AVAudioEngine for noise reduction
        let format = audioEngine.inputNode.outputFormat(forBus: 0)
        
        // Add EQ node for frequency filtering
        noiseSuppressionNode = AVAudioUnitEQ(numberOfBands: 10)
        audioEngine.attach(noiseSuppressionNode!)
        
        // Configure bands for voice frequency emphasis (85-255 Hz)
        configureVoiceFrequencyBands()
        
        // Apply noise gate
        applyNoiseGate(threshold: -40.0) // dB
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        // Apply spectral subtraction for noise reduction
        // Enhance voice frequencies
        // Suppress background noise
        return enhancedBuffer
    }
}
```

#### Multi-Language Recognition
```swift
class MultiLanguageRecognizer {
    private var recognizers: [String: SFSpeechRecognizer] = [:]
    private var activeRecognizer: SFSpeechRecognizer?
    
    func configureLanguages() {
        let supportedLocales = [
            "en-US", "es-ES", "fr-FR", "de-DE", "ja-JP",
            "zh-CN", "ko-KR", "it-IT", "pt-BR", "ru-RU",
            "ar-SA", "hi-IN", "nl-NL", "sv-SE", "pl-PL"
        ]
        
        for localeIdentifier in supportedLocales {
            if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) {
                recognizers[localeIdentifier] = recognizer
            }
        }
    }
    
    func detectLanguage(from audioBuffer: AVAudioPCMBuffer) async -> String? {
        // Parallel language detection using multiple recognizers
        let detectionTasks = recognizers.map { (locale, recognizer) in
            Task {
                let confidence = await tryRecognition(
                    buffer: audioBuffer,
                    recognizer: recognizer
                )
                return (locale: locale, confidence: confidence)
            }
        }
        
        let results = await withTaskGroup(of: (String, Float).self) { group in
            for task in detectionTasks {
                group.addTask { await task.value }
            }
            
            var topResult: (locale: String, confidence: Float) = ("", 0.0)
            for await result in group {
                if result.1 > topResult.confidence {
                    topResult = result
                }
            }
            return topResult
        }
        
        return results.confidence > 0.7 ? results.locale : nil
    }
}
```

#### Live Transcription Streaming
```swift
class LiveTranscriptionStream {
    private let resultPublisher = PassthroughSubject<TranscriptionResult, Error>()
    private var partialResultBuffer = ""
    private var streamingSession: URLSession?
    
    func startStreaming() {
        recognitionRequest?.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(
            with: recognitionRequest!
        ) { [weak self] result, error in
            if let result = result {
                // Process partial result
                let transcription = self?.processPartialResult(result)
                
                // Publish to subscribers
                self?.resultPublisher.send(transcription!)
                
                // Update UI with partial text
                if !result.isFinal {
                    self?.handlePartialResult(transcription!)
                } else {
                    self?.handleFinalResult(transcription!)
                }
            }
            
            if let error = error {
                self?.handleRecognitionError(error)
            }
        }
    }
    
    func processPartialResult(_ result: SFSpeechRecognitionResult) -> TranscriptionResult {
        let bestTranscription = result.bestTranscription
        
        // Extract segments with timing
        let segments = bestTranscription.segments.map { segment in
            TranscriptionSegment(
                substring: segment.substring,
                substringRange: segment.substringRange,
                timestamp: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence,
                alternativeSubstrings: segment.alternativeSubstrings
            )
        }
        
        // Build alternatives
        let alternatives = result.transcriptions.prefix(3).map { transcription in
            AlternativeTranscription(
                text: transcription.formattedString,
                confidence: transcription.confidence,
                likelihood: transcription.likelihood
            )
        }
        
        return TranscriptionResult(
            text: bestTranscription.formattedString,
            confidence: bestTranscription.confidence,
            segments: segments,
            alternatives: alternatives,
            isFinal: result.isFinal,
            timestamp: Date(),
            duration: result.speechRecognitionMetadata?.duration ?? 0
        )
    }
}
```

## 2. Gemini 2.5 Pro API Integration for Translation

### 2.1 API Configuration

#### Endpoint & Authentication
```swift
struct GeminiAPIConfig {
    static let baseURL = "https://generativelanguage.googleapis.com"
    static let apiVersion = "v1beta"
    static let model = "gemini-2.0-flash-exp"
    
    static var translationEndpoint: String {
        "\(baseURL)/\(apiVersion)/models/\(model):generateContent"
    }
    
    // Secure API key storage
    static var apiKey: String {
        KeychainManager.shared.retrieve(key: "gemini_api_key") ?? ""
    }
    
    static let defaultHeaders: [String: String] = [
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey
    ]
}
```

### 2.2 Translation Request Structure

#### Input Parameters
```swift
struct TranslationRequest: Codable {
    let contents: [Content]
    let generationConfig: GenerationConfig
    let safetySettings: [SafetySetting]
    
    struct Content: Codable {
        let parts: [Part]
        let role: String = "user"
    }
    
    struct Part: Codable {
        let text: String
    }
    
    struct GenerationConfig: Codable {
        let temperature: Float = 0.3  // Low for consistency
        let topK: Int = 40
        let topP: Float = 0.95
        let maxOutputTokens: Int = 2048
        let stopSequences: [String] = []
    }
    
    struct SafetySetting: Codable {
        let category: String
        let threshold: String = "BLOCK_NONE"
    }
    
    init(textToTranslate: String, sourceLanguage: String, targetLanguage: String) {
        // Validate input
        guard textToTranslate.count <= 10000 else {
            fatalError("Text exceeds maximum character limit of 10,000")
        }
        
        // Build translation prompt
        let prompt = """
        Translate the following text from \(sourceLanguage) to \(targetLanguage).
        Provide only the translation without any explanation or additional text.
        
        Text to translate:
        \(textToTranslate)
        """
        
        self.contents = [
            Content(parts: [Part(text: prompt)])
        ]
        
        self.generationConfig = GenerationConfig()
        
        self.safetySettings = [
            SafetySetting(category: "HARM_CATEGORY_HARASSMENT"),
            SafetySetting(category: "HARM_CATEGORY_HATE_SPEECH"),
            SafetySetting(category: "HARM_CATEGORY_SEXUALLY_EXPLICIT"),
            SafetySetting(category: "HARM_CATEGORY_DANGEROUS_CONTENT")
        ]
    }
}
```

#### Expected Response Structure
```swift
struct TranslationResponse: Codable {
    let candidates: [Candidate]
    let usageMetadata: UsageMetadata
    
    struct Candidate: Codable {
        let content: Content
        let finishReason: String
        let index: Int
        let safetyRatings: [SafetyRating]
    }
    
    struct Content: Codable {
        let parts: [Part]
        let role: String
    }
    
    struct Part: Codable {
        let text: String
    }
    
    struct UsageMetadata: Codable {
        let promptTokenCount: Int
        let candidatesTokenCount: Int
        let totalTokenCount: Int
    }
    
    struct SafetyRating: Codable {
        let category: String
        let probability: String
    }
    
    var translatedText: String? {
        candidates.first?.content.parts.first?.text
    }
}
```

### 2.3 Rate Limiting Implementation

```swift
class RateLimiter {
    private let maxRequestsPerMinute = 60
    private var requestTimestamps: [Date] = []
    private let queue = DispatchQueue(label: "rate.limiter.queue")
    
    func canMakeRequest() -> Bool {
        queue.sync {
            let now = Date()
            let oneMinuteAgo = now.addingTimeInterval(-60)
            
            // Remove timestamps older than 1 minute
            requestTimestamps.removeAll { $0 < oneMinuteAgo }
            
            // Check if under limit
            return requestTimestamps.count < maxRequestsPerMinute
        }
    }
    
    func recordRequest() {
        queue.async {
            self.requestTimestamps.append(Date())
        }
    }
    
    func timeUntilNextRequest() -> TimeInterval? {
        queue.sync {
            guard requestTimestamps.count >= maxRequestsPerMinute else {
                return nil
            }
            
            let oldestRequest = requestTimestamps.first!
            let availableTime = oldestRequest.addingTimeInterval(60)
            return availableTime.timeIntervalSince(Date())
        }
    }
}

class ExponentialBackoff {
    private var retryCount = 0
    private let maxRetries = 5
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 32.0
    
    func nextDelay() -> TimeInterval? {
        guard retryCount < maxRetries else { return nil }
        
        let delay = min(baseDelay * pow(2.0, Double(retryCount)), maxDelay)
        retryCount += 1
        
        // Add jitter (±10%)
        let jitter = delay * 0.1 * (Double.random(in: -1...1))
        return delay + jitter
    }
    
    func reset() {
        retryCount = 0
    }
}
```

### 2.4 Request Queue Management

```swift
class TranslationRequestQueue {
    private var queue: [TranslationTask] = []
    private let maxQueueSize = 100
    private let processingQueue = DispatchQueue(label: "translation.queue")
    private var isProcessing = false
    
    struct TranslationTask {
        let id: UUID
        let request: TranslationRequest
        let completion: (Result<TranslationResponse, Error>) -> Void
        let priority: Priority
        let timestamp: Date
        
        enum Priority: Int {
            case low = 0
            case normal = 1
            case high = 2
        }
    }
    
    func enqueue(_ task: TranslationTask) throws {
        guard queue.count < maxQueueSize else {
            throw QueueError.queueFull
        }
        
        processingQueue.async {
            self.queue.append(task)
            self.queue.sort { $0.priority.rawValue > $1.priority.rawValue }
            self.processNextIfPossible()
        }
    }
    
    private func processNextIfPossible() {
        guard !isProcessing,
              !queue.isEmpty,
              RateLimiter.shared.canMakeRequest() else {
            return
        }
        
        isProcessing = true
        let task = queue.removeFirst()
        
        Task {
            do {
                let response = try await executeTranslation(task.request)
                task.completion(.success(response))
            } catch {
                handleTranslationError(error, task: task)
            }
            
            processingQueue.async {
                self.isProcessing = false
                self.processNextIfPossible()
            }
        }
    }
}
```

### 2.5 Error Handling

```swift
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

class TranslationErrorHandler {
    func handle(_ error: Error, request: TranslationRequest) async throws -> TranslationResponse {
        switch error {
        case TranslationError.networkTimeout:
            // Retry with extended timeout
            return try await retryWithTimeout(request, timeout: 60)
            
        case TranslationError.invalidLanguageCode(let code):
            // Fallback to auto-detect
            var modifiedRequest = request
            if code == request.sourceLanguage {
                modifiedRequest.sourceLanguage = "auto"
            }
            return try await executeTranslation(modifiedRequest)
            
        case TranslationError.rateLimitExceeded(let retryAfter):
            // Queue for later
            try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
            return try await executeTranslation(request)
            
        case TranslationError.translationFailed:
            // Try alternative prompt format
            return try await retryWithAlternativePrompt(request)
            
        default:
            throw error
        }
    }
    
    private func retryWithAlternativePrompt(_ request: TranslationRequest) async throws -> TranslationResponse {
        // Modify prompt for better results
        let alternativePrompt = """
        Task: Translation
        Source Language: \(request.sourceLanguage)
        Target Language: \(request.targetLanguage)
        
        Input:
        \(request.textToTranslate)
        
        Output (translation only):
        """
        
        var modifiedRequest = request
        modifiedRequest.prompt = alternativePrompt
        return try await executeTranslation(modifiedRequest)
    }
}
```

## 3. Gemini 2.5 Pro API Integration for Text-to-Speech (TTS)

### 3.1 TTS API Configuration

```swift
struct GeminiTTSConfig {
    static let ttsEndpoint = "\(GeminiAPIConfig.baseURL)/\(GeminiAPIConfig.apiVersion)/models/\(GeminiAPIConfig.model):synthesizeSpeech"
    
    struct VoiceParameters {
        let gender: Gender
        let speakingRate: Float  // 0.75 - 1.25
        let pitch: Float         // -20.0 to 20.0
        let volumeGainDb: Float  // -96.0 to 16.0
        
        enum Gender: String, Codable {
            case male = "MALE"
            case female = "FEMALE"
            case neutral = "NEUTRAL"
        }
        
        static let `default` = VoiceParameters(
            gender: .neutral,
            speakingRate: 1.0,
            pitch: 0.0,
            volumeGainDb: 0.0
        )
    }
}
```

### 3.2 TTS Request Structure

```swift
struct TTSRequest: Codable {
    let input: SynthesisInput
    let voice: VoiceSelectionParams
    let audioConfig: AudioConfig
    
    struct SynthesisInput: Codable {
        let text: String
    }
    
    struct VoiceSelectionParams: Codable {
        let languageCode: String
        let name: String?
        let ssmlGender: String
    }
    
    struct AudioConfig: Codable {
        let audioEncoding: String = "MP3"
        let speakingRate: Float
        let pitch: Float
        let volumeGainDb: Float
        let sampleRateHertz: Int = 24000
        let effectsProfileId: [String] = ["headphone-class-device"]
    }
    
    init(text: String, languageCode: String, voiceParams: GeminiTTSConfig.VoiceParameters) {
        self.input = SynthesisInput(text: text)
        
        self.voice = VoiceSelectionParams(
            languageCode: languageCode,
            name: VoiceSelector.selectVoice(for: languageCode),
            ssmlGender: voiceParams.gender.rawValue
        )
        
        self.audioConfig = AudioConfig(
            speakingRate: voiceParams.speakingRate,
            pitch: voiceParams.pitch,
            volumeGainDb: voiceParams.volumeGainDb
        )
    }
}
```

### 3.3 TTS Response Handling

```swift
struct TTSResponse: Codable {
    let audioContent: String  // Base64-encoded audio
    let audioMetadata: AudioMetadata?
    
    struct AudioMetadata: Codable {
        let duration: TimeInterval
        let sampleRate: Int
        let encoding: String
        let channels: Int
    }
    
    func decodeAudio() throws -> Data {
        guard let audioData = Data(base64Encoded: audioContent) else {
            throw TTSError.invalidAudioData
        }
        return audioData
    }
    
    func saveToFile(url: URL) throws {
        let audioData = try decodeAudio()
        try audioData.write(to: url)
    }
}
```

### 3.4 Voice Selection Logic

```swift
class VoiceSelector {
    private static let voiceMapping: [String: [String]] = [
        "en": ["en-US-Wavenet-D", "en-US-Neural2-J", "en-US-Studio-M"],
        "es": ["es-ES-Wavenet-B", "es-ES-Neural2-A", "es-ES-Studio-F"],
        "fr": ["fr-FR-Wavenet-C", "fr-FR-Neural2-B", "fr-FR-Studio-A"],
        "de": ["de-DE-Wavenet-F", "de-DE-Neural2-B", "de-DE-Studio-B"],
        "ja": ["ja-JP-Wavenet-D", "ja-JP-Neural2-B", "ja-JP-Studio-B"],
        "zh": ["cmn-CN-Wavenet-C", "cmn-CN-Neural2-A", "cmn-CN-Studio-A"],
        "ko": ["ko-KR-Wavenet-A", "ko-KR-Neural2-A", "ko-KR-Studio-A"],
        "it": ["it-IT-Wavenet-D", "it-IT-Neural2-A", "it-IT-Studio-A"],
        "pt": ["pt-BR-Wavenet-B", "pt-BR-Neural2-A", "pt-BR-Studio-B"],
        "ru": ["ru-RU-Wavenet-C", "ru-RU-Neural2-A", "ru-RU-Studio-D"]
    ]
    
    static func selectVoice(for languageCode: String) -> String? {
        let language = languageCode.prefix(2).lowercased()
        let voices = voiceMapping[String(language)] ?? []
        
        // Priority: User preference > Neural2 > Wavenet > Studio
        if let userPreferred = UserDefaults.standard.string(forKey: "voice_\(language)") {
            return userPreferred
        }
        
        return voices.first(where: { $0.contains("Neural2") }) ??
               voices.first(where: { $0.contains("Wavenet") }) ??
               voices.first
    }
    
    static func fallbackVoice(for languageCode: String) -> String {
        // Generic fallback voices for unsupported languages
        return "en-US-Neural2-J"  // Default to English
    }
}
```

### 3.5 TTS Error Handling

```swift
enum TTSError: Error {
    case generationFailed(String)
    case unsupportedLanguage(String)
    case unsupportedVoice(String)
    case invalidAudioData
    case audioFormatConversionFailed
    case voiceNotAvailable
}

class TTSErrorHandler {
    func handle(_ error: TTSError, request: TTSRequest) async throws -> TTSResponse {
        switch error {
        case .unsupportedLanguage(let lang):
            // Use fallback language
            var modifiedRequest = request
            modifiedRequest.voice.languageCode = "en"  // Fallback to English
            return try await executeTTS(modifiedRequest)
            
        case .unsupportedVoice:
            // Try with default voice
            var modifiedRequest = request
            modifiedRequest.voice.name = nil  // Let API choose
            return try await executeTTS(modifiedRequest)
            
        case .generationFailed:
            // Retry with simplified text
            var modifiedRequest = request
            modifiedRequest.input.text = simplifyText(request.input.text)
            return try await executeTTS(modifiedRequest)
            
        case .audioFormatConversionFailed:
            // Request different format
            var modifiedRequest = request
            modifiedRequest.audioConfig.audioEncoding = "LINEAR16"
            return try await executeTTS(modifiedRequest)
            
        default:
            throw error
        }
    }
    
    private func simplifyText(_ text: String) -> String {
        // Remove special characters and simplify
        let simplified = text.replacingOccurrences(
            of: "[^a-zA-Z0-9\\s.,!?]",
            with: "",
            options: .regularExpression
        )
        return simplified
    }
}
```

## 4. Data Flow & Logic

### 4.1 Complete Translation Pipeline

```swift
class TranslationPipeline {
    private let speechRecognizer = SpeechRecognitionManager()
    private let translator = GeminiTranslationService()
    private let ttsService = GeminiTTSService()
    private let audioPlayer = AudioPlayerManager()
    
    func processTranslation() async throws {
        // Step 1: Capture audio
        let audioBuffer = try await captureAudio()
        
        // Step 2: Speech-to-Text
        let transcription = try await speechRecognizer.recognize(audioBuffer)
        
        // Step 3: Validate and prepare text
        let preparedText = preprocessText(transcription.text)
        
        // Step 4: Detect/validate language codes
        let (sourceCode, targetCode) = try validateLanguagePair(
            source: currentSourceLanguage,
            target: currentTargetLanguage
        )
        
        // Step 5: Translate via Gemini
        let translation = try await translator.translate(
            text: preparedText,
            from: sourceCode,
            to: targetCode
        )
        
        // Step 6: Generate speech via Gemini TTS
        let audioData = try await ttsService.synthesize(
            text: translation.text,
            language: targetCode
        )
        
        // Step 7: Play audio
        try await audioPlayer.play(audioData)
    }
}
```

### 4.2 Language Code Management

```swift
class LanguageCodeMapper {
    // ISO 639-1 mapping
    private static let iso639Mapping: [String: LanguageInfo] = [
        "en": LanguageInfo(code: "en", name: "English", nativeName: "English", bcp47: "en-US"),
        "es": LanguageInfo(code: "es", name: "Spanish", nativeName: "Español", bcp47: "es-ES"),
        "fr": LanguageInfo(code: "fr", name: "French", nativeName: "Français", bcp47: "fr-FR"),
        "de": LanguageInfo(code: "de", name: "German", nativeName: "Deutsch", bcp47: "de-DE"),
        "ja": LanguageInfo(code: "ja", name: "Japanese", nativeName: "日本語", bcp47: "ja-JP"),
        "zh": LanguageInfo(code: "zh", name: "Chinese", nativeName: "中文", bcp47: "zh-CN"),
        "ko": LanguageInfo(code: "ko", name: "Korean", nativeName: "한국어", bcp47: "ko-KR"),
        "it": LanguageInfo(code: "it", name: "Italian", nativeName: "Italiano", bcp47: "it-IT"),
        "pt": LanguageInfo(code: "pt", name: "Portuguese", nativeName: "Português", bcp47: "pt-BR"),
        "ru": LanguageInfo(code: "ru", name: "Russian", nativeName: "Русский", bcp47: "ru-RU"),
        "ar": LanguageInfo(code: "ar", name: "Arabic", nativeName: "العربية", bcp47: "ar-SA"),
        "hi": LanguageInfo(code: "hi", name: "Hindi", nativeName: "हिन्दी", bcp47: "hi-IN"),
        "nl": LanguageInfo(code: "nl", name: "Dutch", nativeName: "Nederlands", bcp47: "nl-NL"),
        "sv": LanguageInfo(code: "sv", name: "Swedish", nativeName: "Svenska", bcp47: "sv-SE"),
        "pl": LanguageInfo(code: "pl", name: "Polish", nativeName: "Polski", bcp47: "pl-PL")
    ]
    
    struct LanguageInfo {
        let code: String      // ISO 639-1
        let name: String      // English name
        let nativeName: String
        let bcp47: String     // BCP 47 tag for speech APIs
    }
    
    static func validate(_ code: String) -> Bool {
        return iso639Mapping[code] != nil
    }
    
    static func autoDetect(from text: String) async -> String? {
        // Use Gemini for language detection
        let prompt = "Detect the language of this text and return only the ISO 639-1 code: \(text)"
        let response = try? await GeminiAPIClient.shared.generate(prompt: prompt)
        return response?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func validatePair(source: String, target: String) -> Bool {
        // Check if language pair is supported
        let supportedPairs = loadSupportedPairs()
        return supportedPairs.contains { $0.source == source && $0.target == target }
    }
}
```

### 4.3 Cache Management

```swift
class TranslationCache {
    private let cache = NSCache<NSString, CachedTranslation>()
    private let diskCache = DiskCache(directory: "translations")
    private let maxMemoryItems = 100
    private let maxDiskSize = 50 * 1024 * 1024  // 50MB
    
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
    }
    
    func store(_ translation: CachedTranslation) {
        // Memory cache
        cache.setObject(translation, forKey: translation.cacheKey as NSString)
        
        // Disk cache for offline
        Task {
            try? await diskCache.store(
                translation,
                key: translation.cacheKey
            )
        }
    }
    
    func retrieve(text: String, source: String, target: String) -> CachedTranslation? {
        let key = "\(source)_\(target)_\(text.hashValue)"
        
        // Check memory cache first
        if let cached = cache.object(forKey: key as NSString) {
            // Check if not expired (24 hours)
            if Date().timeIntervalSince(cached.timestamp) < 86400 {
                return cached
            }
        }
        
        // Check disk cache
        return try? diskCache.retrieve(key: key)
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
}
```

## 5. Error Handling Strategy

### 5.1 Comprehensive Error Management

```swift
class ErrorHandlingCoordinator {
    enum ErrorCategory {
        case stt
        case network
        case api
        case audio
        case system
    }
    
    func handleError(_ error: Error) -> ErrorRecoveryStrategy {
        switch error {
        // STT Failures
        case is SpeechRecognitionError:
            return handleSTTError(error as! SpeechRecognitionError)
            
        // Network Failures
        case is URLError:
            return handleNetworkError(error as! URLError)
            
        // API Failures
        case is TranslationError:
            return handleAPIError(error as! TranslationError)
            
        // Audio Failures
        case is AVAudioSession.ErrorCode:
            return handleAudioError(error)
            
        default:
            return .showAlert(
                title: "Unexpected Error",
                message: error.localizedDescription,
                actions: [.retry, .cancel]
            )
        }
    }
    
    private func handleSTTError(_ error: SpeechRecognitionError) -> ErrorRecoveryStrategy {
        switch error {
        case .audioEngineFailure:
            return .retry(
                after: 1.0,
                withFallback: .switchToTextInput
            )
            
        case .recognizerUnavailable:
            return .fallback(to: .manualTextInput)
            
        case .noSpeechDetected:
            return .showToast(
                "No speech detected. Please try again.",
                duration: 3.0
            )
            
        case .permissionDenied:
            return .requestPermission(
                type: .microphone,
                message: "Microphone access is required for speech recognition"
            )
        }
    }
    
    private func handleNetworkError(_ error: URLError) -> ErrorRecoveryStrategy {
        switch error.code {
        case .notConnectedToInternet:
            return .switchToOfflineMode(
                withCache: true,
                showMessage: "No internet connection. Using offline mode."
            )
            
        case .timedOut:
            return .retry(
                after: 2.0,
                maxAttempts: 3,
                withBackoff: true
            )
            
        case .networkConnectionLost:
            return .queue(
                forLaterExecution: true,
                notifyUser: "Connection lost. Will retry when connected."
            )
            
        default:
            return .showAlert(
                title: "Network Error",
                message: "Please check your connection",
                actions: [.retry, .cancel]
            )
        }
    }
}

enum ErrorRecoveryStrategy {
    case retry(after: TimeInterval, maxAttempts: Int = 3, withBackoff: Bool = false)
    case fallback(to: FallbackOption)
    case switchToOfflineMode(withCache: Bool, showMessage: String)
    case queue(forLaterExecution: Bool, notifyUser: String)
    case showAlert(title: String, message: String, actions: [AlertAction])
    case showToast(String, duration: TimeInterval)
    case requestPermission(type: PermissionType, message: String)
    
    enum FallbackOption {
        case manualTextInput
        case cachedTranslation
        case alternativeAPI
    }
}
```

## 6. Security Considerations

### 6.1 API Key Management

```swift
class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.universaltranslator.api"
    
    func store(apiKey: String, for service: APIService) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: service.rawValue,
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    func retrieve(for service: APIService) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: self.service,
            kSecAttrAccount as String: service.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return apiKey
    }
    
    func rotate(for service: APIService, newKey: String) throws {
        // Delete old key
        try delete(for: service)
        
        // Store new key
        try store(apiKey: newKey, for: service)
        
        // Notify services of rotation
        NotificationCenter.default.post(
            name: .apiKeyRotated,
            object: service
        )
    }
    
    enum APIService: String {
        case gemini = "gemini_api"
        case backup = "backup_api"
    }
}
```

### 6.2 Data Privacy

```swift
class PrivacyManager {
    static let shared = PrivacyManager()
    
    struct PrivacySettings {
        var storeTranslations: Bool = false
        var shareAnalytics: Bool = false
        var useCloudBackup: Bool = false
        var allowPersonalization: Bool = true
    }
    
    func configurePrivacy() {
        // No persistent storage by default
        TranslationCache.shared.setPersistence(enabled: settings.storeTranslations)
        
        // Analytics opt-out
        Analytics.shared.setEnabled(settings.shareAnalytics)
        
        // Disable cloud sync if requested
        CloudSync.shared.setEnabled(settings.useCloudBackup)
    }
    
    func requestConsent(for feature: PrivacyFeature) async -> Bool {
        // Show consent dialog
        let consent = await ConsentDialog.show(for: feature)
        
        // Store consent
        UserDefaults.standard.set(consent, forKey: "consent_\(feature.rawValue)")
        
        // Apply settings
        applyConsentSettings(feature: feature, granted: consent)
        
        return consent
    }
    
    func deleteAllUserData() async throws {
        // Clear caches
        TranslationCache.shared.clearAll()
        
        // Delete stored translations
        try FileManager.default.removeItem(at: documentsDirectory)
        
        // Clear keychain
        try KeychainManager.shared.deleteAll()
        
        // Reset user defaults
        UserDefaults.standard.removePersistentDomain(
            forName: Bundle.main.bundleIdentifier!
        )
    }
}
```

### 6.3 Network Security

```swift
class NetworkSecurityManager {
    static let shared = NetworkSecurityManager()
    
    func configureSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        
        // TLS 1.3 minimum
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
        
        // Certificate pinning
        let pinnedCertificates = loadPinnedCertificates()
        
        let session = URLSession(
            configuration: configuration,
            delegate: PinningDelegate(certificates: pinnedCertificates),
            delegateQueue: nil
        )
        
        return session
    }
    
    class PinningDelegate: NSObject, URLSessionDelegate {
        private let pinnedCertificates: [SecCertificate]
        
        init(certificates: [SecCertificate]) {
            self.pinnedCertificates = certificates
            super.init()
        }
        
        func urlSession(
            _ session: URLSession,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            
            // Validate certificate
            let isValid = validateCertificate(serverTrust)
            
            if isValid {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        }
        
        private func validateCertificate(_ trust: SecTrust) -> Bool {
            // Implement certificate validation logic
            var error: CFError?
            let isValid = SecTrustEvaluateWithError(trust, &error)
            
            guard isValid else { return false }
            
            // Additional pinning check
            let certificateCount = SecTrustGetCertificateCount(trust)
            for index in 0..<certificateCount {
                if let certificate = SecTrustGetCertificateAtIndex(trust, index) {
                    if pinnedCertificates.contains(certificate) {
                        return true
                    }
                }
            }
            
            return false
        }
    }
}
```

## 7. Key Backend Deliverables

### 7.1 SpeechRecognitionManager Class

```swift
// Complete implementation
class SpeechRecognitionManager: NSObject {
    // Properties
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Public API
    func startRecognition(language: String) async throws -> TranscriptionResult
    func stopRecognition()
    func pauseRecognition()
    func resumeRecognition()
    func configureAudioSession() throws
}
```

### 7.2 GeminiAPIClient Singleton

```swift
// Singleton implementation
class GeminiAPIClient {
    static let shared = GeminiAPIClient()
    
    private let session: URLSession
    private let rateLimiter = RateLimiter()
    private let requestQueue = TranslationRequestQueue()
    
    func translate(_ request: TranslationRequest) async throws -> TranslationResponse
    func synthesizeSpeech(_ request: TTSRequest) async throws -> TTSResponse
    func detectLanguage(_ text: String) async throws -> String
}
```

### 7.3 TranslationService Protocol

```swift
protocol TranslationService {
    func translate(text: String, from: String, to: String) async throws -> Translation
    func detectLanguage(text: String) async throws -> String
    func getSupportedLanguages() -> [Language]
    func validateLanguagePair(source: String, target: String) -> Bool
}

class GeminiTranslationService: TranslationService {
    // Implementation
}
```

### 7.4 TTSService Protocol

```swift
protocol TTSService {
    func synthesize(text: String, language: String, voice: VoiceParameters?) async throws -> AudioData
    func getAvailableVoices(for language: String) -> [Voice]
    func preloadVoice(_ voice: Voice) async throws
}

class GeminiTTSService: TTSService {
    // Implementation
}
```

### 7.5 AudioSessionManager

```swift
class AudioSessionManager {
    private let audioSession = AVAudioSession.sharedInstance()
    
    func configureForRecording() throws
    func configureForPlayback() throws
    func handleInterruption(_ notification: Notification)
    func handleRouteChange(_ notification: Notification)
}
```

### 7.6 NetworkReachability Monitor

```swift
class NetworkReachability {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "network.monitor")
    
    var isConnected: Bool { currentPath.status == .satisfied }
    var isExpensive: Bool { currentPath.isExpensive }
    var isConstrained: Bool { currentPath.isConstrained }
    
    func startMonitoring()
    func stopMonitoring()
}
```

### 7.7 CacheManager

```swift
class CacheManager {
    private let memoryCache = NSCache<NSString, CachedItem>()
    private let diskCache: DiskCache
    
    func store(_ item: Cacheable, key: String) async throws
    func retrieve(_ key: String) async -> Cacheable?
    func clear() async throws
    func setMaxSize(_ bytes: Int)
}
```

---

**Document Version**: 1.0  
**Last Updated**: 2025-08-03  
**API Version**: Gemini 2.5 Pro  
**Platform**: iOS 15.0+  
**Status**: Ready for Implementation