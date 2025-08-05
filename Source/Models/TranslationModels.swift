import Foundation

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
        let temperature: Float = 0.3
        let topK: Int = 40
        let topP: Float = 0.95
        let maxOutputTokens: Int = 2048
        let stopSequences: [String] = []
    }
    
    struct SafetySetting: Codable {
        let category: String
        let threshold: String = "BLOCK_NONE"
    }
    
    init(textToTranslate: String, sourceLanguage: String, targetLanguage: String) throws {
        guard textToTranslate.count <= 10000 else {
            throw TranslationError.textTooLong
        }
        
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

struct Translation: Codable {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let confidence: Float
    let timestamp: Date
}