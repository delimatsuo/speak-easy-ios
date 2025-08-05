import Foundation
import Speech
import AVFoundation
import XCTest

// MARK: - Mock Network Protocol
class MockURLProtocol: URLProtocol {
    static var mockResponses: [URL: MockResponse] = [:]
    static var requestHandler: ((URLRequest) -> (HTTPURLResponse, Data?))?
    
    struct MockResponse {
        let data: Data?
        let response: HTTPURLResponse
        let error: Error?
        let delay: TimeInterval?
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let url = request.url else { return }
        
        if let mockResponse = Self.mockResponses[url] {
            // Simulate network delay if specified
            if let delay = mockResponse.delay {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.deliverMockResponse(mockResponse)
                }
            } else {
                deliverMockResponse(mockResponse)
            }
        } else if let handler = Self.requestHandler {
            let (response, data) = handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    override func stopLoading() {}
    
    private func deliverMockResponse(_ mockResponse: MockResponse) {
        if let error = mockResponse.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocol(self, didReceive: mockResponse.response, cacheStoragePolicy: .notAllowed)
            if let data = mockResponse.data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    
    static func reset() {
        mockResponses.removeAll()
        requestHandler = nil
    }
    
    static func addMockResponse(url: URL, response: MockResponse) {
        mockResponses[url] = response
    }
}

// MARK: - Mock Gemini API
class MockGeminiAPI {
    static let shared = MockGeminiAPI()
    
    private var translationResponses: [String: String] = [:]
    private var ttsResponses: [String: Data] = [:]
    private var shouldSimulateRateLimit = false
    private var shouldSimulateNetworkError = false
    private var responseDelay: TimeInterval = 0
    
    private init() {}
    
    func reset() {
        translationResponses.removeAll()
        ttsResponses.removeAll()
        shouldSimulateRateLimit = false
        shouldSimulateNetworkError = false
        responseDelay = 0
    }
    
    // MARK: - Translation Mocking
    func setTranslationResponse(for input: String, response: String) {
        translationResponses[input] = response
    }
    
    func getSuccessTranslationResponse(translatedText: String) -> Data {
        let response = """
        {
            "candidates": [{
                "content": {
                    "parts": [{"text": "\(translatedText)"}],
                    "role": "model"
                },
                "finishReason": "STOP",
                "index": 0,
                "safetyRatings": [
                    {"category": "HARM_CATEGORY_HARASSMENT", "probability": "NEGLIGIBLE"},
                    {"category": "HARM_CATEGORY_HATE_SPEECH", "probability": "NEGLIGIBLE"}
                ]
            }],
            "usageMetadata": {
                "promptTokenCount": 15,
                "candidatesTokenCount": 8,
                "totalTokenCount": 23
            }
        }
        """
        return response.data(using: .utf8)!
    }
    
    func getRateLimitResponse() -> Data {
        let response = """
        {
            "error": {
                "code": 429,
                "message": "Quota exceeded",
                "status": "RESOURCE_EXHAUSTED",
                "details": [{
                    "@type": "type.googleapis.com/google.rpc.ErrorInfo",
                    "reason": "RATE_LIMIT_EXCEEDED",
                    "domain": "googleapis.com"
                }]
            }
        }
        """
        return response.data(using: .utf8)!
    }
    
    func getInvalidAPIKeyResponse() -> Data {
        let response = """
        {
            "error": {
                "code": 401,
                "message": "API key not valid",
                "status": "UNAUTHENTICATED"
            }
        }
        """
        return response.data(using: .utf8)!
    }
    
    // MARK: - TTS Mocking
    func setTTSResponse(for text: String, audioData: Data) {
        ttsResponses[text] = audioData
    }
    
    func getSuccessTTSResponse(audioData: Data) -> Data {
        let base64Audio = audioData.base64EncodedString()
        let response = """
        {
            "audioContent": "\(base64Audio)",
            "audioMetadata": {
                "duration": 2.5,
                "sampleRate": 24000,
                "encoding": "MP3",
                "channels": 1
            }
        }
        """
        return response.data(using: .utf8)!
    }
    
    // MARK: - Error Simulation
    func simulateRateLimit(_ enable: Bool) {
        shouldSimulateRateLimit = enable
    }
    
    func simulateNetworkError(_ enable: Bool) {
        shouldSimulateNetworkError = enable
    }
    
    func setResponseDelay(_ delay: TimeInterval) {
        responseDelay = delay
    }
    
    // MARK: - Mock URL Session Configuration
    func configureMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        
        // Setup mock responses for Gemini endpoints
        setupTranslationEndpointMocks()
        setupTTSEndpointMocks()
        
        return URLSession(configuration: config)
    }
    
    private func setupTranslationEndpointMocks() {
        let translationURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent")!
        
        MockURLProtocol.requestHandler = { [weak self] request in
            guard let self = self else {
                return (HTTPURLResponse(), nil)
            }
            
            if self.shouldSimulateNetworkError {
                let response = HTTPURLResponse(url: translationURL, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, nil)
            }
            
            if self.shouldSimulateRateLimit {
                let response = HTTPURLResponse(url: translationURL, statusCode: 429, httpVersion: nil, headerFields: nil)!
                return (response, self.getRateLimitResponse())
            }
            
            // Parse request body to determine response
            if let body = request.httpBody,
               let requestData = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let contents = requestData["contents"] as? [[String: Any]],
               let parts = contents.first?["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                
                // Extract text to translate from prompt
                if let translatedText = self.extractTranslationFromPrompt(text) {
                    let response = HTTPURLResponse(url: translationURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
                    return (response, self.getSuccessTranslationResponse(translatedText: translatedText))
                }
            }
            
            let response = HTTPURLResponse(url: translationURL, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, self.getSuccessTranslationResponse(translatedText: "Default translation"))
        }
    }
    
    private func setupTTSEndpointMocks() {
        let ttsURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:synthesizeSpeech")!
        
        // Create mock audio data
        let mockAudioData = createMockAudioData()
        
        let mockResponse = MockURLProtocol.MockResponse(
            data: getSuccessTTSResponse(audioData: mockAudioData),
            response: HTTPURLResponse(url: ttsURL, statusCode: 200, httpVersion: nil, headerFields: nil)!,
            error: nil,
            delay: responseDelay > 0 ? responseDelay : nil
        )
        
        MockURLProtocol.addMockResponse(url: ttsURL, response: mockResponse)
    }
    
    private func extractTranslationFromPrompt(_ prompt: String) -> String? {
        // Simple extraction for test purposes
        if prompt.contains("Hello") {
            return "Hola"
        } else if prompt.contains("Thank you") {
            return "Gracias"
        } else if prompt.contains("Good morning") {
            return "Buenos días"
        }
        return "Traducción de prueba"
    }
    
    private func createMockAudioData() -> Data {
        // Create minimal MP3-like data for testing
        let mockMp3Header: [UInt8] = [0xFF, 0xFB, 0x90, 0x00] // MP3 sync word and header
        return Data(mockMp3Header + Array(repeating: 0, count: 1024))
    }
}

// MARK: - Mock Speech Recognizer
class MockSpeechRecognizer {
    static let shared = MockSpeechRecognizer()
    
    private var recognitionResults: [String: MockRecognitionResult] = [:]
    private var shouldSimulateError = false
    private var recognitionDelay: TimeInterval = 0.1
    
    struct MockRecognitionResult {
        let text: String
        let confidence: Float
        let isFinal: Bool
        let segments: [MockSegment]
    }
    
    struct MockSegment {
        let substring: String
        let confidence: Float
        let timestamp: TimeInterval
        let duration: TimeInterval
    }
    
    private init() {
        setupDefaultResults()
    }
    
    func reset() {
        recognitionResults.removeAll()
        shouldSimulateError = false
        recognitionDelay = 0.1
        setupDefaultResults()
    }
    
    private func setupDefaultResults() {
        // Setup common test phrases
        setRecognitionResult(
            for: "test_hello",
            result: MockRecognitionResult(
                text: "Hello, how are you today?",
                confidence: 0.95,
                isFinal: true,
                segments: [
                    MockSegment(substring: "Hello", confidence: 0.98, timestamp: 0.0, duration: 0.4),
                    MockSegment(substring: "how", confidence: 0.97, timestamp: 0.5, duration: 0.2),
                    MockSegment(substring: "are", confidence: 0.96, timestamp: 0.8, duration: 0.2),
                    MockSegment(substring: "you", confidence: 0.98, timestamp: 1.1, duration: 0.3),
                    MockSegment(substring: "today", confidence: 0.94, timestamp: 1.5, duration: 0.5)
                ]
            )
        )
        
        setRecognitionResult(
            for: "test_spanish",
            result: MockRecognitionResult(
                text: "Hola, ¿cómo estás?",
                confidence: 0.92,
                isFinal: true,
                segments: [
                    MockSegment(substring: "Hola", confidence: 0.96, timestamp: 0.0, duration: 0.4),
                    MockSegment(substring: "cómo", confidence: 0.89, timestamp: 0.6, duration: 0.4),
                    MockSegment(substring: "estás", confidence: 0.91, timestamp: 1.2, duration: 0.5)
                ]
            )
        )
    }
    
    func setRecognitionResult(for key: String, result: MockRecognitionResult) {
        recognitionResults[key] = result
    }
    
    func simulateError(_ enable: Bool) {
        shouldSimulateError = enable
    }
    
    func setRecognitionDelay(_ delay: TimeInterval) {
        recognitionDelay = delay
    }
    
    func getRecognitionResult(for key: String) -> MockRecognitionResult? {
        return recognitionResults[key]
    }
    
    // Simulate speech recognition permission states
    enum PermissionState {
        case notDetermined
        case authorized
        case denied
        case restricted
    }
    
    private var mockPermissionState: PermissionState = .authorized
    
    func setMockPermissionState(_ state: PermissionState) {
        mockPermissionState = state
    }
    
    func getMockPermissionState() -> PermissionState {
        return mockPermissionState
    }
}

// MARK: - Mock Network Service
class MockNetworkService {
    static let shared = MockNetworkService()
    
    private var isConnected = true
    private var connectionType: ConnectionType = .wifi
    private var latency: TimeInterval = 0.1
    
    enum ConnectionType {
        case wifi
        case cellular
        case none
    }
    
    private init() {}
    
    func reset() {
        isConnected = true
        connectionType = .wifi
        latency = 0.1
    }
    
    func simulateConnectionState(_ connected: Bool) {
        isConnected = connected
        if !connected {
            connectionType = .none
        }
    }
    
    func simulateConnectionType(_ type: ConnectionType) {
        connectionType = type
        isConnected = type != .none
    }
    
    func simulateLatency(_ latency: TimeInterval) {
        self.latency = latency
    }
    
    func getConnectionState() -> Bool {
        return isConnected
    }
    
    func getConnectionType() -> ConnectionType {
        return connectionType
    }
    
    func getLatency() -> TimeInterval {
        return latency
    }
}

// MARK: - Mock Cache Manager
class MockCacheManager {
    static let shared = MockCacheManager()
    
    private var memoryCache: [String: Any] = [:]
    private var diskCache: [String: Data] = [:]
    private var cacheHits = 0
    private var cacheMisses = 0
    
    private init() {}
    
    func reset() {
        memoryCache.removeAll()
        diskCache.removeAll()
        cacheHits = 0
        cacheMisses = 0
    }
    
    func store(_ object: Any, forKey key: String) {
        memoryCache[key] = object
        if let data = object as? Data {
            diskCache[key] = data
        }
    }
    
    func retrieve(forKey key: String) -> Any? {
        if let object = memoryCache[key] {
            cacheHits += 1
            return object
        }
        cacheMisses += 1
        return nil
    }
    
    func retrieveData(forKey key: String) -> Data? {
        if let data = diskCache[key] {
            cacheHits += 1
            return data
        }
        cacheMisses += 1
        return nil
    }
    
    func getCacheStats() -> (hits: Int, misses: Int) {
        return (cacheHits, cacheMisses)
    }
    
    func getCacheSize() -> Int {
        return memoryCache.count
    }
}

// MARK: - Mock Language Detector
class MockLanguageDetector {
    static let shared = MockLanguageDetector()
    
    private var languageMap: [String: String] = [:]
    
    private init() {
        setupDefaultLanguageMap()
    }
    
    private func setupDefaultLanguageMap() {
        languageMap = [
            "Hello": "en",
            "Hola": "es",
            "Bonjour": "fr",
            "Hallo": "de",
            "こんにちは": "ja",
            "你好": "zh",
            "안녕하세요": "ko",
            "Ciao": "it",
            "Olá": "pt",
            "Привет": "ru"
        ]
    }
    
    func detectLanguage(from text: String) -> String? {
        for (phrase, language) in languageMap {
            if text.contains(phrase) {
                return language
            }
        }
        return "en" // Default to English
    }
    
    func setLanguageMapping(_ text: String, language: String) {
        languageMap[text] = language
    }
    
    func reset() {
        languageMap.removeAll()
        setupDefaultLanguageMap()
    }
}