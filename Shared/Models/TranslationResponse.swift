//
//  TranslationResponse.swift
//  UniversalTranslator
//
//  Shared model for iPhone to Watch translation responses
//

import Foundation

struct TranslationResponse: Codable, Equatable {
    let requestId: UUID
    let originalText: String
    let translatedText: String
    let audioData: Data?
    let error: String?
    let creditsRemaining: Int
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "requestId": requestId.uuidString,
            "originalText": originalText,
            "translatedText": translatedText,
            "creditsRemaining": creditsRemaining
        ]
        
        if let audioData = audioData {
            dict["audioData"] = audioData
        }
        
        if let error = error {
            dict["error"] = error
        }
        
        return dict
    }
    
    init(requestId: UUID, originalText: String, translatedText: String, audioData: Data?, error: String?, creditsRemaining: Int) {
        self.requestId = requestId
        self.originalText = originalText
        self.translatedText = translatedText
        self.audioData = audioData
        self.error = error
        self.creditsRemaining = creditsRemaining
    }
    
    init?(from dictionary: [String: Any]) {
        guard let requestIdString = dictionary["requestId"] as? String,
              let requestId = UUID(uuidString: requestIdString),
              let originalText = dictionary["originalText"] as? String,
              let translatedText = dictionary["translatedText"] as? String,
              let creditsRemaining = dictionary["creditsRemaining"] as? Int else {
            return nil
        }
        
        self.requestId = requestId
        self.originalText = originalText
        self.translatedText = translatedText
        self.audioData = dictionary["audioData"] as? Data
        self.error = dictionary["error"] as? String
        self.creditsRemaining = creditsRemaining
    }
}