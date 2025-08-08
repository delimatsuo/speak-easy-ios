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
    
    @Published var isTranslating = false
    @Published var lastError: String?
    @Published var translationHistory: [TranslationHistory] = []
    
    // Network retry configuration
    private let maxRetryAttempts = 2
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 5.0
    private let requestTimeoutSeconds: TimeInterval = 30.0
    
    // Current request tracking for cancellation
    private var currentTask: URLSessionDataTask?
    private var requestStartTime: Date?
    private var currentCancellable: Task<Void, Never>?
    
    // Cancellation tracking
    @Published var isCancelling = false
    
    private init() {
        Task {
            await loadTranslationHistory()
        }
    }
    
    // MARK: - Voice Translation API
    
    func translateWithAudio(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> TranslationAudioResponse {
        // Reset any previous error state
        await MainActor.run {
            self.lastError = nil
            self.isCancelling = false
        }
        
        // Test health endpoint first
        let isHealthy = await checkAPIHealth()
        if !isHealthy {
            print("⚠️ [\(Date())] API health check failed, attempting fallback to text-only translation")
            return try await translateTextOnly(text: text, from: sourceLanguage, to: targetLanguage)
        }
        
        return try await performWithRetry {
            try await self.translateWithAudioInternal(text: text, from: sourceLanguage, to: targetLanguage)
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
        print("🔄 [\(Date())] Making translation request to: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = requestTimeoutSeconds
        
        // Track request start time for timeout monitoring
        requestStartTime = Date()
        print("⏰ [\(Date())] Request timeout set to \(requestTimeoutSeconds) seconds")
        
        // Securely retrieve API key using APIKeyManager
        if let apiKey = APIKeyManager.shared.getAPIKey() {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            print("🔑 API key configured: \(apiKey.prefix(10))...")
        } else {
            print("❌ No API key found")
            throw TranslationError.apiError("API key not configured")
        }
        
        let body = TranslationAudioRequest(
            text: text,
            source_language: sourceLanguage,
            target_language: targetLanguage,
            return_audio: true,
            voice_gender: "neutral",
            speaking_rate: 1.0
        )
        
        request.httpBody = try JSONEncoder().encode(body)
        print("📤 [\(Date())] Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "invalid")")
        
        do {
            // Create a more aggressive timeout with cancellation support
            let result = try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                // Add the network request task
                group.addTask {
                    // Check for cancellation before making request
                    try Task.checkCancellation()
                    
                    let (data, response) = try await URLSession.shared.data(for: request)
                    
                    // Check for cancellation after receiving response
                    try Task.checkCancellation()
                    
                    print("📥 [\(Date())] Received response: \(data.count) bytes")
                    if let startTime = self.requestStartTime {
                        let duration = Date().timeIntervalSince(startTime)
                        print("⏱️ [\(Date())] Request completed in \(String(format: "%.2f", duration)) seconds")
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
            
            print("📊 [\(Date())] HTTP Status: \(httpResponse.statusCode)")
            print("📋 [\(Date())] Response headers: \(httpResponse.allHeaderFields)")
            
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ [\(Date())] API Error Response (\(httpResponse.statusCode)): \(errorBody)")
                
                // Store error for UI display
                await MainActor.run {
                    self.lastError = "Server error (\(httpResponse.statusCode)): \(errorBody)"
                }
                
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw TranslationError.apiError(errorResponse.detail)
                } else {
                    throw TranslationError.httpError(httpResponse.statusCode)
                }
            }
            
            let audioResponse = try JSONDecoder().decode(TranslationAudioResponse.self, from: data)
            print("✅ [\(Date())] Translation successful: \(audioResponse.translatedText)")
            
            // Clear any previous errors
            await MainActor.run {
                self.lastError = nil
            }
            
            // Save to history with audio URL
            await saveTranslationToHistory(
                originalText: text,
                translatedText: audioResponse.translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                audioURL: audioResponse.audioURL
            )
            
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
            
            let errorMessage: String
            if error.code == .timedOut {
                errorMessage = "Translation request timed out after \(String(format: "%.0f", duration)) seconds"
                await MainActor.run {
                    self.lastError = errorMessage
                }
                throw TranslationError.timeout
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
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
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
        request.timeoutInterval = 10.0 // Much shorter timeout for health check
        
        // Use withTimeout for aggressive timeout enforcement
        let result = try await withTimeout(seconds: 10) {
            try await URLSession.shared.data(for: request)
        }
        
        let (data, response) = result
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TranslationError.invalidResponse
        }
        
        let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
        return healthResponse.status == "healthy"
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
    
    private func saveTranslationToHistory(
        originalText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        audioURL: String? = nil
    ) async {
        let historyData: [String: Any] = [
            "originalText": originalText,
            "translatedText": translatedText,
            "sourceLanguage": sourceLanguage,
            "targetLanguage": targetLanguage,
            "timestamp": FieldValue.serverTimestamp(),
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "hasAudio": audioURL != nil,
            "audioURL": audioURL ?? ""
        ]
        
        do {
            try await db.collection("translations").addDocument(data: historyData)
            await self.loadTranslationHistory()
        } catch {
            print("Failed to save translation history: \(error)")
        }
    }
    
    func loadTranslationHistory() async {
        do {
            let snapshot = try await db.collection("translations")
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let history = snapshot.documents.compactMap { document -> TranslationHistory? in
                try? document.data(as: TranslationHistory.self)
            }
            
            await MainActor.run {
                self.translationHistory = history
            }
        } catch {
            print("Failed to load translation history: \(error)")
        }
    }
    
    func clearHistory() async {
        do {
            let snapshot = try await db.collection("translations").getDocuments()
            
            for document in snapshot.documents {
                try await document.reference.delete()
            }
            
            await MainActor.run {
                self.translationHistory = []
            }
        } catch {
            print("Failed to clear history: \(error)")
        }
    }
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
        Language(code: "en", name: "English", flag: "🇺🇸"),
        Language(code: "es", name: "Spanish", flag: "🇪🇸"),
        Language(code: "fr", name: "French", flag: "🇫🇷"),
        Language(code: "de", name: "German", flag: "🇩🇪"),
        Language(code: "it", name: "Italian", flag: "🇮🇹"),
        Language(code: "pt", name: "Portuguese", flag: "🇵🇹"),
        Language(code: "ru", name: "Russian", flag: "🇷🇺"),
        Language(code: "ja", name: "Japanese", flag: "🇯🇵"),
        Language(code: "ko", name: "Korean", flag: "🇰🇷"),
        Language(code: "zh", name: "Chinese", flag: "🇨🇳"),
        Language(code: "ar", name: "Arabic", flag: "🇸🇦"),
        Language(code: "hi", name: "Hindi", flag: "🇮🇳")
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

enum TranslationError: LocalizedError {
    case emptyText
    case invalidResponse
    case invalidURL
    case httpError(Int)
    case apiError(String)
    case networkError
    case timeout
    case audioDownloadFailed
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Please speak something to translate"
        case .invalidResponse:
            return "Invalid response from translation server"
        case .invalidURL:
            return "Invalid audio URL provided by server"
        case .httpError(let code):
            switch code {
            case 400:
                return "Bad request - please check your input"
            case 401:
                return "Authentication failed - please check API key"
            case 403:
                return "Access forbidden - API key may be invalid"
            case 404:
                return "Translation service not found"
            case 429:
                return "Too many requests - please wait and try again"
            case 500...599:
                return "Server error (\(code)) - please try again later"
            default:
                return "Server error (Code: \(code))"
            }
        case .apiError(let message):
            return message.isEmpty ? "Translation API error" : message
        case .networkError:
            return "Network connection failed - please check your internet connection"
        case .timeout:
            return "Translation timed out after 30 seconds. The server appears unresponsive - please try again later."
        case .audioDownloadFailed:
            return "Failed to download translation audio"
        case .cancelled:
            return "Translation was cancelled"
        }
    }
}

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