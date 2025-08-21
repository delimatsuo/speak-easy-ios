//
//  TranslationService.swift
//  UniversalTranslator
//
//  Service for handling voice translations with audio responses
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Security
import UIKit

class TranslationService: ObservableObject {
    static let shared = TranslationService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let secureSession: URLSession = NetworkSecurityManager.shared.configureSession()
    
    @Published var isTranslating = false
    @Published var lastError: String?
    @Published var translationHistory: [TranslationHistory] = []
    
    // Network retry configuration - optimized for faster user experience
    private let maxRetryAttempts = 2
    private let baseRetryDelay: TimeInterval = 0.5  // Reduced from 1.0s
    private let maxRetryDelay: TimeInterval = 3.0   // Reduced from 5.0s
    private let requestTimeoutSeconds: TimeInterval = 20.0  // Reduced from 30.0s
    
    // Current request tracking for cancellation
    private var currentTask: URLSessionDataTask?
    private var requestStartTime: Date?
    private var currentCancellable: Task<Void, Never>?
    
    // Cancellation tracking
    @Published var isCancelling = false
    
    private init() {}
    
    // MARK: - Voice Translation API
    
    func translateWithAudio(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> TranslationAudioResponse {
        // Reset any previous error state
        await MainActor.run {
            self.lastError = nil
            self.isCancelling = false
        }
        
        // Skip health check - just try the translation directly
        // Health checks add unnecessary latency and can fail due to network issues
        print("🔄 Starting translation without health check")
        
        return try await performWithRetry {
            try await self.translateWithAudioInternal(text: text, from: sourceLanguage, to: targetLanguage)
        }
    }

    // MARK: - Remote Speech-to-Text Fallback
    func remoteSpeechToText(audioURL: URL, language: String) async throws -> String {
        print("🎙️ Starting remote speech-to-text for language: \(language)")
        
        let url = URL(string: "\(NetworkConfig.apiBaseURL)\(NetworkConfig.Endpoint.speechToText)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        // Read audio file and prepare payload
        let audioData = try Data(contentsOf: audioURL)
        let audioBase64 = audioData.base64EncodedString()
        
        // Detect audio format based on file extension
        let fileExtension = audioURL.pathExtension.lowercased()
        let encoding = fileExtension == "m4a" ? "M4A" : "MP3"
        
        let payload: [String: Any] = [
            "audio_base64": audioBase64,
            "language_code": language,
            "encoding": encoding,
            "sample_rate": 44100
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("📤 Sending audio (\(audioData.count) bytes, \(encoding) format) to server STT")

        do {
            let (responseData, response) = try await secureSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranslationError.apiError("Invalid response from speech-to-text server")
            }
            
            print("📥 Server STT response: HTTP \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                print("❌ Server STT error: \(errorBody)")
                throw TranslationError.apiError("Speech-to-text failed (HTTP \(httpResponse.statusCode))")
            }
            
            guard let jsonResponse = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let transcription = jsonResponse["transcription"] as? String,
                  !transcription.isEmpty else {
                print("❌ Server STT returned empty or invalid transcription")
                throw TranslationError.apiError("Server could not transcribe the audio - please speak clearly and try again")
            }
            
            print("✅ Server STT successful: \"\(transcription.prefix(50))...\"")
            return transcription
            
        } catch {
            print("❌ Server STT failed: \(error)")
            throw error
        }
    }
    
    // Fallback method for text-only translation when audio endpoint fails
    private func translateTextOnly(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> TranslationAudioResponse {
        // Create a mock audio response with just the translated text
        // In a real implementation, you might have a separate text-only endpoint
        throw TranslationError.apiError("Translation service is currently unavailable. Please try again later.")
    }
    
    // Cancel current translation request
    func cancelCurrentTranslation() {
        print("🚫 [\(Date())] Cancelling current translation request")
        
        Task { @MainActor in
            self.isCancelling = true
        }
        
        currentTask?.cancel()
        currentCancellable?.cancel()
        
        Task { @MainActor in
            self.isTranslating = false
            self.lastError = "Translation cancelled by user"
        }
    }
    
    private func translateWithAudioInternal(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> TranslationAudioResponse {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyText
        }
        
        let url = URL(string: "\(NetworkConfig.apiBaseURL)\(NetworkConfig.Endpoint.translateAudio)")!
        #if DEBUG
        print("🔄 [\(Date())] Making translation request to: \(url)")
        #endif
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = requestTimeoutSeconds
        
        // Track request start time for timeout monitoring
        requestStartTime = Date()
        #if DEBUG
        print("⏰ [\(Date())] Request timeout set to \(requestTimeoutSeconds) seconds")
        #endif
        
        // Optionally attach API key if configured (not required for backend using Secret Manager)
        if let apiKey = APIKeyManager.shared.getAPIKey() {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            // Do not log API key
        }
        
        let body = TranslationAudioRequest(
            text: text,
            source_language: sourceLanguage,
            target_language: targetLanguage,
            return_audio: true,
            voice_gender: "neutral",
            speaking_rate: 0.90
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        #if DEBUG
        print("📤 [\(Date())] Request body length: \(request.httpBody?.count ?? 0) bytes")
        #endif
        
        do {
            // Create a more aggressive timeout with cancellation support
            let session = secureSession
            let result = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                // Add the network request task
                group.addTask {
                    // Check for cancellation before making request
                    try Task.checkCancellation()
                    
                    let (data, response) = try await session.data(for: request)
                    
                    // Check for cancellation after receiving response
                    try Task.checkCancellation()
                    
                    #if DEBUG
                    print("📥 [\(Date())] Received response: \(data.count) bytes")
                    #endif
                    if let startTime = self.requestStartTime {
                        let duration = Date().timeIntervalSince(startTime)
                        #if DEBUG
                        print("⏱️ [\(Date())] Request completed in \(String(format: "%.2f", duration)) seconds")
                        #endif
                    }
                    return (data, response)
                }
                
                // Add a more aggressive timeout task
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(self.requestTimeoutSeconds * 1_000_000_000))
                    print("⏰ [\(Date())] Request timeout reached after \(self.requestTimeoutSeconds) seconds")
                    throw TranslationError.timeout
                }
                
                // Add cancellation check task
                group.addTask {
                    while !Task.isCancelled {
                        try await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5s
                        if await self.isCancelling {
                            throw TranslationError.cancelled
                        }
                    }
                    throw TranslationError.cancelled
                }
                
                // Return the first completed task (either success, timeout, or cancellation)
                let result = try await group.next()!
                group.cancelAll() // Cancel all other tasks
                return result
            }
            
            let (data, response) = result
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [\(Date())] Invalid HTTP response type")
                throw TranslationError.invalidResponse
            }
            
            #if DEBUG
            print("📊 [\(Date())] HTTP Status: \(httpResponse.statusCode)")
            #endif
            
            if httpResponse.statusCode != 200 {
                #if DEBUG
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [\(Date())] API Error Response (\(httpResponse.statusCode)): \(errorBody)")
                #endif

                // Store error for UI display
                await MainActor.run {
                    #if DEBUG
                    let dbg = String(data: data, encoding: .utf8) ?? ""
                    self.lastError = "Server error (\(httpResponse.statusCode)): \(dbg)"
                    #else
                    self.lastError = "Server error (\(httpResponse.statusCode))"
                    #endif
                }
                
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw TranslationError.apiError(errorResponse.detail)
                } else {
                    throw TranslationError.httpError(httpResponse.statusCode)
                }
            }
            
            let audioResponse = try JSONDecoder().decode(TranslationAudioResponse.self, from: data)
            #if DEBUG
            print("✅ [\(Date())] Translation successful")
            #endif
            
            // Clear any previous errors
            await MainActor.run {
                self.lastError = nil
            }
            
            // Conversation content is NOT persisted by policy
            
            // If audio is base64 encoded, decode it
            if let audioBase64 = audioResponse.audioBase64 {
                audioResponse.audioData = Data(base64Encoded: audioBase64)
            }
            
            // If audio URL is provided, download it with retry
            if audioResponse.audioData == nil, let audioURLString = audioResponse.audioURL {
                audioResponse.audioData = try await self.downloadAudioWithRetry(from: audioURLString)
            }
            
            return audioResponse
            
        } catch let error as URLError {
            let duration = requestStartTime.map { Date().timeIntervalSince($0) } ?? 0
            print("❌ [\(Date())] Network Error after \(String(format: "%.2f", duration))s: \(error.localizedDescription) (Code: \(error.code.rawValue))")
            print("   URL Error Code: \(error.code)")
            print("   Failed URL: \(error.failingURL?.absoluteString ?? "unknown")")
            
            let errorMessage: String
            if error.code == .timedOut {
                errorMessage = "Translation request timed out after \(String(format: "%.0f", duration)) seconds"
                await MainActor.run {
                    self.lastError = errorMessage
                }
                throw TranslationError.timeout
            } else if error.code == .cannotConnectToHost || error.code == .networkConnectionLost {
                errorMessage = "Cannot connect to translation server. Please check your internet connection."
                await MainActor.run {
                    self.lastError = errorMessage
                }
                throw TranslationError.networkError
            } else if error.code == .secureConnectionFailed {
                errorMessage = "Secure connection failed. Please try again."
                await MainActor.run {
                    self.lastError = errorMessage
                }
                throw TranslationError.networkError
            } else {
                errorMessage = "Network error: \(error.localizedDescription)"
                await MainActor.run {
                    self.lastError = errorMessage
                }
                throw TranslationError.networkError
            }
        } catch let translationError as TranslationError {
            let duration = requestStartTime.map { Date().timeIntervalSince($0) } ?? 0
            print("❌ [\(Date())] Translation Error after \(String(format: "%.2f", duration))s: \(translationError.localizedDescription)")
            await MainActor.run {
                self.lastError = translationError.localizedDescription
            }
            throw translationError
        } catch {
            let duration = requestStartTime.map { Date().timeIntervalSince($0) } ?? 0
            print("❌ [\(Date())] Unexpected Error after \(String(format: "%.2f", duration))s: \(error)")
            await MainActor.run {
                self.lastError = "Unexpected error: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    // MARK: - Audio Download
    
    private func downloadAudio(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw TranslationError.invalidURL
        }
        
        let (data, response) = try await secureSession.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.audioDownloadFailed
        }
        
        return data
    }
    
    private func downloadAudioWithRetry(from urlString: String) async throws -> Data {
        return try await performWithRetry {
            try await self.downloadAudio(from: urlString)
        }
    }
    
    // MARK: - Network Retry Logic
    
    private func performWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxRetryAttempts {
            do {
                print("🔄 [\(Date())] Translation attempt \(attempt)/\(maxRetryAttempts)")
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry on certain errors
                if let translationError = error as? TranslationError {
                    switch translationError {
                    case .emptyText, .invalidURL:
                        print("❌ [\(Date())] Non-retryable error: \(translationError.localizedDescription)")
                        throw error // Don't retry these errors
                    case .apiError(let message):
                        // Don't retry 4xx client errors, but retry 5xx server errors
                        if message.contains("4") && (message.contains("400") || message.contains("401") || message.contains("403") || message.contains("404")) {
                            print("❌ [\(Date())] Client error, not retrying: \(message)")
                            throw error
                        }
                        print("⚠️ [\(Date())] Server error on attempt \(attempt), may retry: \(message)")
                    case .timeout:
                        print("⏰ [\(Date())] Translation request timed out on attempt \(attempt)/\(maxRetryAttempts)")
                        // Don't retry timeouts on audio endpoint - fallback to text-only
                        if attempt == 1 {
                            print("🔄 [\(Date())] Audio endpoint timeout, attempting text-only fallback")
                            throw TranslationError.timeout // Will trigger fallback in main method
                        }
                    case .cancelled:
                        print("🚫 [\(Date())] Translation request was cancelled")
                        throw error // Don't retry cancellations
                    case .httpError(let code):
                        if code >= 400 && code < 500 {
                            print("❌ [\(Date())] Client HTTP error \(code), not retrying")
                            throw error
                        }
                        print("⚠️ [\(Date())] Server HTTP error \(code) on attempt \(attempt), may retry")
                    default:
                        print("⚠️ [\(Date())] Network error on attempt \(attempt): \(translationError.localizedDescription)")
                        break
                    }
                }
                
                // If this was the last attempt, throw the error
                if attempt == maxRetryAttempts {
                    print("❌ [\(Date())] All \(maxRetryAttempts) attempts failed, throwing error: \(error.localizedDescription)")
                    
                    // For timeout errors, suggest text-only fallback
                    let errorMsg = if let translationError = error as? TranslationError, case .timeout = translationError {
                        "Translation service is unresponsive. Audio translation is temporarily unavailable."
                    } else {
                        "Translation failed after \(maxRetryAttempts) attempts: \(error.localizedDescription)"
                    }
                    
                    await MainActor.run {
                        self.lastError = errorMsg
                    }
                    throw error
                }
                
                // Calculate delay with exponential backoff
                let multiplier = Double(1 << (attempt - 1)) // 2^(attempt-1) using bit shifting
                let delay = min(baseRetryDelay * multiplier, maxRetryDelay)
                print("🔄 [\(Date())] Retrying in \(String(format: "%.1f", delay)) seconds (attempt \(attempt)/\(maxRetryAttempts))")
                
                // Update UI with retry status
                await MainActor.run {
                    self.lastError = "Attempt \(attempt) failed, retrying in \(Int(delay))s..."
                }
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // This should never be reached, but just in case
        throw lastError ?? TranslationError.networkError
    }
    
    // MARK: - Language Support
    
    func fetchSupportedLanguages() async throws -> [Language] {
        return try await performWithRetry {
            try await self.fetchSupportedLanguagesInternal()
        }
    }
    
    private func fetchSupportedLanguagesInternal() async throws -> [Language] {
        let url = URL(string: "\(NetworkConfig.apiBaseURL)\(NetworkConfig.Endpoint.languages)")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.invalidResponse
        }
        
        let languageResponse = try JSONDecoder().decode(LanguageResponse.self, from: data)
        return languageResponse.languages
    }
    
    // MARK: - Health Check
    
    func checkAPIHealth() async -> Bool {
        print("🔍 [\(Date())] Starting quick API health check...")
        do {
            // Use a faster, single-attempt health check
            let isHealthy = try await checkAPIHealthInternal()
            print(isHealthy ? "✅ [\(Date())] API health check passed" : "❌ [\(Date())] API health check failed")
            return isHealthy
        } catch {
            print("❌ [\(Date())] Health check failed: \(error)")
            return false
        }
    }
    
    // Comprehensive connection test
    func testFullConnection() async -> ConnectionTestResult {
        print("🧪 [\(Date())] Starting comprehensive connection test...")
        var results = ConnectionTestResult()
        
        // Test 1: Health endpoint
        do {
            let healthStartTime = Date()
            let isHealthy = try await checkAPIHealthInternal()
            let healthDuration = Date().timeIntervalSince(healthStartTime)
            
            results.healthCheck = isHealthy
            results.healthCheckDuration = healthDuration
            print("🏥 [\(Date())] Health check: \(isHealthy ? "✅ PASS" : "❌ FAIL") (\(String(format: "%.2f", healthDuration))s)")
        } catch {
            results.healthCheck = false
            results.healthCheckError = error.localizedDescription
            print("🏥 [\(Date())] Health check: ❌ FAIL - \(error.localizedDescription)")
        }
        
        // Test 2: Languages endpoint
        do {
            let langStartTime = Date()
            let languages = try await fetchSupportedLanguagesInternal()
            let langDuration = Date().timeIntervalSince(langStartTime)
            
            results.languagesCheck = true
            results.languagesCount = languages.count
            results.languagesCheckDuration = langDuration
            print("🌐 [\(Date())] Languages check: ✅ PASS (\(languages.count) languages, \(String(format: "%.2f", langDuration))s)")
        } catch {
            results.languagesCheck = false
            results.languagesCheckError = error.localizedDescription
            print("🌐 [\(Date())] Languages check: ❌ FAIL - \(error.localizedDescription)")
        }
        
        // Test 3: Simple translation
        do {
            let transStartTime = Date()
            let _ = try await translateWithAudioInternal(
                text: "Hello",
                from: "en",
                to: "es"
            )
            let transDuration = Date().timeIntervalSince(transStartTime)
            
            results.translationCheck = true
            results.translationCheckDuration = transDuration
            print("🔤 [\(Date())] Translation check: ✅ PASS (\(String(format: "%.2f", transDuration))s)")
        } catch {
            results.translationCheck = false
            results.translationCheckError = error.localizedDescription
            print("🔤 [\(Date())] Translation check: ❌ FAIL - \(error.localizedDescription)")
        }
        
        results.overallSuccess = results.healthCheck && results.languagesCheck && results.translationCheck
        print("🧪 [\(Date())] Connection test complete: \(results.overallSuccess ? "✅ ALL PASS" : "❌ SOME FAILED")")
        
        return results
    }
    
    private func checkAPIHealthInternal() async throws -> Bool {
        let url = URL(string: "\(NetworkConfig.apiBaseURL)\(NetworkConfig.Endpoint.health)")!
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0 // Optimized timeout for health check
        
        // Use withTimeout for aggressive timeout enforcement
            let session = secureSession
            let result = try await withTimeout(seconds: 5) {
                 try await session.data(for: request)
            }
        
        let (data, response) = result
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.invalidResponse
        }
        
        let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
        // Treat 'degraded' as acceptable for client use; backend may still serve translations
        return healthResponse.status == "healthy" || healthResponse.status == "degraded"
    }
    
    // Helper function for timeout enforcement
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TranslationError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Firebase Operations
    
    // History APIs removed per privacy policy: no conversation content is stored.
}

// MARK: - Models

struct TranslationAudioRequest: Codable {
    let text: String
    let source_language: String
    let target_language: String
    let return_audio: Bool
    let voice_gender: String // "male", "female", "neutral"
    let speaking_rate: Float // 0.5 to 2.0
}

class TranslationAudioResponse: Codable {
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let confidence: Float
    let audioURL: String?
    let audioBase64: String?
    var audioData: Data?
    
    enum CodingKeys: String, CodingKey {
        case translatedText = "translated_text"
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
        case confidence
        case audioURL = "audio_url"
        case audioBase64 = "audio_base64"
    }
}

struct TranslationHistory: Codable, Identifiable {
    @DocumentID var id: String?
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date?
    let deviceId: String?
    let hasAudio: Bool
    let audioURL: URL?
}

struct Language: Codable, Identifiable {
    let code: String
    let name: String
    let flag: String
    
    var id: String { code }
    
    static let defaultLanguages = [
        // Original languages - ONLY GEMINI 2.5 FLASH TTS SUPPORTED
        Language(code: "en", name: "English", flag: "🇺🇸"),
        Language(code: "es", name: "Spanish", flag: "🇪🇸"),
        Language(code: "fr", name: "French", flag: "🇫🇷"),
        Language(code: "de", name: "German", flag: "🇩🇪"),
        Language(code: "it", name: "Italian", flag: "🇮🇹"),
        Language(code: "pt", name: "Portuguese", flag: "🇧🇷"),
        Language(code: "ru", name: "Russian", flag: "🇷🇺"),
        Language(code: "ja", name: "Japanese", flag: "🇯🇵"),
        Language(code: "ko", name: "Korean", flag: "🇰🇷"),
        Language(code: "zh", name: "Chinese", flag: "🇨🇳"),
        Language(code: "ar", name: "Arabic", flag: "🇸🇦"),
        Language(code: "hi", name: "Hindi", flag: "🇮🇳"),
        
        // Phase 1: Major Market Languages
        Language(code: "id", name: "Indonesian", flag: "🇮🇩"),
        // REMOVED: Filipino (fil) - Not supported by Gemini 2.5 Flash TTS
        Language(code: "vi", name: "Vietnamese", flag: "🇻🇳"),
        Language(code: "tr", name: "Turkish", flag: "🇹🇷"),
        Language(code: "th", name: "Thai", flag: "🇹🇭"),
        Language(code: "pl", name: "Polish", flag: "🇵🇱"),
        
        // Phase 2: Regional Powerhouses
        Language(code: "bn", name: "Bengali", flag: "🇧🇩"),
        Language(code: "te", name: "Telugu", flag: "🇮🇳"),
        Language(code: "mr", name: "Marathi", flag: "🇮🇳"),
        Language(code: "ta", name: "Tamil", flag: "🇮🇳"),
        Language(code: "uk", name: "Ukrainian", flag: "🇺🇦"),
        Language(code: "ro", name: "Romanian", flag: "🇷🇴")
    ]
    
    static func name(for code: String) -> String {
        defaultLanguages.first { $0.code == code }?.name ?? code.uppercased()
    }
}

struct LanguageResponse: Codable {
    let languages: [Language]
}

struct HealthResponse: Codable {
    let status: String
    let version: String
    let environment: String
    let timestamp: String
    let uptime_seconds: Double?
}

struct ErrorResponse: Codable {
    let error: String
    let detail: String
    let timestamp: String
    let request_id: String?
}

// MARK: - Errors

// TranslationError enum is now defined in Shared/Models/TranslationError.swift
// to share with the Watch app

// MARK: - Connection Test Result

struct ConnectionTestResult {
    var overallSuccess = false
    
    var healthCheck = false
    var healthCheckDuration: TimeInterval = 0
    var healthCheckError: String?
    
    var languagesCheck = false
    var languagesCount = 0
    var languagesCheckDuration: TimeInterval = 0
    var languagesCheckError: String?
    
    var translationCheck = false
    var translationCheckDuration: TimeInterval = 0
    var translationCheckError: String?
    
    var summary: String {
        var parts: [String] = []
        
        if healthCheck {
            parts.append("✅ Health (\(String(format: "%.1f", healthCheckDuration))s)")
        } else {
            parts.append("❌ Health: \(healthCheckError ?? "Unknown error")")
        }
        
        if languagesCheck {
            parts.append("✅ Languages: \(languagesCount) available (\(String(format: "%.1f", languagesCheckDuration))s)")
        } else {
            parts.append("❌ Languages: \(languagesCheckError ?? "Unknown error")")
        }
        
        if translationCheck {
            parts.append("✅ Translation (\(String(format: "%.1f", translationCheckDuration))s)")
        } else {
            parts.append("❌ Translation: \(translationCheckError ?? "Unknown error")")
        }
        
        return parts.joined(separator: "\n")
    }
}