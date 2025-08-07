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

class TranslationService: ObservableObject {
    static let shared = TranslationService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published var isTranslating = false
    @Published var lastError: String?
    @Published var translationHistory: [TranslationHistory] = []
    
    private init() {
        Task {
            await loadTranslationHistory()
        }
    }
    
    // MARK: - Voice Translation API
    
    func translateWithAudio(text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> TranslationAudioResponse {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyText
        }
        
        let url = URL(string: "\(NetworkConfig.apiBaseURL)\(NetworkConfig.Endpoint.translateAudio)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = NetworkConfig.requestTimeout
        
        // Securely retrieve API key using APIKeyManager
        if let apiKey = APIKeyManager.shared.getAPIKey() {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
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
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TranslationError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                let audioResponse = try JSONDecoder().decode(TranslationAudioResponse.self, from: data)
                
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
                
                // If audio URL is provided, download it
                if audioResponse.audioData == nil, let audioURLString = audioResponse.audioURL {
                    audioResponse.audioData = try await downloadAudio(from: audioURLString)
                }
                
                return audioResponse
            } else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw TranslationError.apiError(errorResponse.detail)
                } else {
                    throw TranslationError.httpError(httpResponse.statusCode)
                }
            }
        } catch {
            print("Translation error: \(error)")
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
    
    // MARK: - Language Support
    
    func fetchSupportedLanguages() async throws -> [Language] {
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
        let url = URL(string: "\(NetworkConfig.apiBaseURL)\(NetworkConfig.Endpoint.health)")!
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
            return healthResponse.status == "healthy"
        } catch {
            print("Health check failed: \(error)")
            return false
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
            await loadTranslationHistory()
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
    case audioDownloadFailed
    
    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Please speak something to translate"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidURL:
            return "Invalid audio URL"
        case .httpError(let code):
            return "Server error (Code: \(code))"
        case .apiError(let message):
            return message
        case .networkError:
            return "Network connection error"
        case .audioDownloadFailed:
            return "Failed to download audio"
        }
    }
}