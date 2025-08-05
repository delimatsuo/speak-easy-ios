import Foundation

struct GeminiAPIConfig {
    // Use configurable base URL from AppConfig
    static var baseURL: String {
        // Check if we should use the configured API base URL or Gemini's specific URL
        let configuredURL = AppConfig.apiBaseURL
        
        // If using local development or custom backend, use that
        if configuredURL.contains("localhost") || configuredURL.contains("run.app") {
            return configuredURL
        }
        
        // Otherwise use Gemini's official API
        return "https://generativelanguage.googleapis.com"
    }
    
    static let apiVersion = "v1beta"
    static let model = "gemini-2.0-flash-exp"
    
    static var translationEndpoint: String {
        if baseURL.contains("generativelanguage.googleapis.com") {
            return "\(baseURL)/\(apiVersion)/models/\(model):generateContent"
        } else {
            // Custom backend endpoint
            return "\(baseURL)\(AppConfig.Endpoints.translation)"
        }
    }
    
    static var ttsEndpoint: String {
        if baseURL.contains("generativelanguage.googleapis.com") {
            return "\(baseURL)/\(apiVersion)/models/\(model):synthesizeSpeech"
        } else {
            // Custom backend endpoint
            return "\(baseURL)\(AppConfig.Endpoints.textToSpeech)"
        }
    }
    
    static var apiKey: String {
        KeychainManager.shared.retrieve(for: .gemini) ?? ""
    }
    
    static var defaultHeaders: [String: String] {
        [
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey
        ]
    }
}

class GeminiAPIClient {
    static let shared = GeminiAPIClient()
    
    private let session: URLSession
    private let rateLimiter = RateLimiter()
    private let requestQueue = TranslationRequestQueue()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let secureWrapper = SecureAPIWrapper.shared
    
    private init() {
        self.session = NetworkSecurityManager.shared.configureSession()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    func translate(_ request: TranslationRequest) async throws -> TranslationResponse {
        let startTime = Date()
        let performanceMonitor = PerformanceMonitor.shared
        
        guard rateLimiter.canMakeRequest() else {
            // GRACEFUL DEGRADATION: Provide detailed rate limiting information
            if let delay = rateLimiter.timeUntilNextRequest() {
                let waitTime = Int(delay.rounded())
                print("Rate limited - suggested wait: \(waitTime) seconds")
                throw TranslationError.rateLimitExceeded(retryAfter: delay)
            }
            // GRACEFUL DEGRADATION: Provide reasonable default wait time
            print("Rate limited - using default wait time")
            throw TranslationError.rateLimitExceeded(retryAfter: 60.0)
        }
        
        rateLimiter.recordRequest()
        
        guard !GeminiAPIConfig.apiKey.isEmpty else {
            throw TranslationError.invalidAPIKey
        }
        
        let url = URL(string: GeminiAPIConfig.translationEndpoint)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 30.0 // Optimized timeout
        
        // SECURITY ENHANCEMENT: Enhanced headers with encryption
        var headers = GeminiAPIConfig.defaultHeaders
        headers["Accept-Encoding"] = "gzip, deflate, br" // Add Brotli compression
        headers["Connection"] = "keep-alive"
        headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        headers["Pragma"] = "no-cache"
        headers["X-Requested-With"] = "XMLHttpRequest"
        headers["X-Content-Type-Options"] = "nosniff"
        
        for (key, value) in headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        let requestData: Data
        do {
            let encodedData = try encoder.encode(request)
            // SECURITY: Sanitize and add integrity checks
            let sanitizedData = secureWrapper.sanitizeRequestData(encodedData)
            secureWrapper.addIntegrityCheck(to: &urlRequest, data: sanitizedData)
            secureWrapper.addRateLimitingHeaders(to: &urlRequest)
            
            requestData = sanitizedData
            urlRequest.httpBody = requestData
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            performanceMonitor.recordAPICall(
                endpoint: "generateContent",
                method: "POST",
                duration: duration,
                responseSize: 0,
                statusCode: 0,
                error: error
            )
            throw TranslationError.invalidResponse
        }
        
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            performanceMonitor.recordAPICall(
                endpoint: "generateContent",
                method: "POST",
                duration: duration,
                responseSize: 0,
                statusCode: 0,
                error: error
            )
            
            if error.localizedDescription.contains("timeout") {
                throw TranslationError.networkTimeout
            }
            throw error
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            let duration = Date().timeIntervalSince(startTime)
            performanceMonitor.recordAPICall(
                endpoint: "generateContent",
                method: "POST",
                duration: duration,
                responseSize: data.count,
                statusCode: 0,
                error: TranslationError.invalidResponse
            )
            throw TranslationError.invalidResponse
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        guard 200...299 ~= httpResponse.statusCode else {
            performanceMonitor.recordAPICall(
                endpoint: "generateContent",
                method: "POST",
                duration: duration,
                responseSize: data.count,
                statusCode: httpResponse.statusCode,
                error: TranslationError.serverError(statusCode: httpResponse.statusCode)
            )
            
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                let delay = TimeInterval(retryAfter ?? "60") ?? 60.0
                throw TranslationError.rateLimitExceeded(retryAfter: delay)
            }
            throw TranslationError.serverError(statusCode: httpResponse.statusCode)
        }
        
        do {
            // SECURITY: Validate response integrity
            guard secureWrapper.validateResponseIntegrity(httpResponse, data: data) else {
                throw TranslationError.invalidResponse
            }
            
            let response = try decoder.decode(TranslationResponse.self, from: data)
            
            // Record successful API call
            performanceMonitor.recordAPICall(
                endpoint: "generateContent",
                method: "POST",
                duration: duration,
                responseSize: data.count,
                statusCode: httpResponse.statusCode
            )
            
            return response
        } catch {
            performanceMonitor.recordAPICall(
                endpoint: "generateContent",
                method: "POST",
                duration: duration,
                responseSize: data.count,
                statusCode: httpResponse.statusCode,
                error: error
            )
            throw TranslationError.invalidResponse
        }
    }
    
    func synthesizeSpeech(_ request: TTSRequest) async throws -> TTSResponse {
        guard rateLimiter.canMakeRequest() else {
            if let delay = rateLimiter.timeUntilNextRequest() {
                throw TranslationError.rateLimitExceeded(retryAfter: delay)
            }
            throw TranslationError.rateLimitExceeded(retryAfter: 60.0)
        }
        
        rateLimiter.recordRequest()
        
        guard !GeminiAPIConfig.apiKey.isEmpty else {
            throw TranslationError.invalidAPIKey
        }
        
        let url = URL(string: GeminiAPIConfig.ttsEndpoint)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        
        for (key, value) in GeminiAPIConfig.defaultHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw TTSError.generationFailed("Failed to encode request")
        }
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.generationFailed("Invalid response")
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 429 {
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                let delay = TimeInterval(retryAfter ?? "60") ?? 60.0
                throw TranslationError.rateLimitExceeded(retryAfter: delay)
            }
            throw TTSError.generationFailed("Server error: \(httpResponse.statusCode)")
        }
        
        do {
            return try decoder.decode(TTSResponse.self, from: data)
        } catch {
            throw TTSError.invalidAudioData
        }
    }
    
    func detectLanguage(_ text: String) async throws -> String {
        let prompt = "Detect the language of this text and return only the ISO 639-1 code: \(text)"
        
        let request: TranslationRequest
        do {
            request = try TranslationRequest(
                textToTranslate: prompt,
                sourceLanguage: "auto",
                targetLanguage: "en"
            )
        } catch {
            throw TranslationError.translationFailed("Failed to create language detection request: \(error.localizedDescription)")
        }
        
        let response = try await translate(request)
        
        guard let detectedLanguage = response.translatedText?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw TranslationError.translationFailed("Could not detect language")
        }
        
        return detectedLanguage
    }
    
    func validateAPIKey() async throws -> Bool {
        let testRequest: TranslationRequest
        do {
            testRequest = try TranslationRequest(
                textToTranslate: "Hello",
                sourceLanguage: "en",
                targetLanguage: "es"
            )
        } catch {
            throw TranslationError.translationFailed("Failed to create validation request: \(error.localizedDescription)")
        }
        
        do {
            _ = try await translate(testRequest)
            return true
        } catch TranslationError.invalidAPIKey {
            return false
        } catch {
            throw error
        }
    }
}

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
              RateLimiter().canMakeRequest() else {
            return
        }
        
        isProcessing = true
        let task = queue.removeFirst()
        
        Task { [weak self] in
            do {
                let response = try await GeminiAPIClient.shared.translate(task.request)
                task.completion(.success(response))
            } catch {
                self?.handleTranslationError(error, task: task)
            }
            
            self?.processingQueue.async { [weak self] in
                self?.isProcessing = false
                self?.processNextIfPossible()
            }
        }
    }
    
    private func handleTranslationError(_ error: Error, task: TranslationTask) {
        if case TranslationError.rateLimitExceeded(let retryAfter) = error {
            DispatchQueue.main.asyncAfter(deadline: .now() + retryAfter) { [weak self] in
                try? self?.enqueue(task)
            }
        } else {
            task.completion(.failure(error))
        }
    }
}