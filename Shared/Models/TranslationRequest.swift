//
//  TranslationRequest.swift
//  UniversalTranslator
//
//  Shared model for Watch to iPhone translation requests
//

import Foundation

struct TranslationRequest: Codable {
    let requestId: UUID
    let sourceLanguage: String
    let targetLanguage: String
    let audioFileURL: URL?
    let audioData: Data?
    let timestamp: Date
    
    init(sourceLanguage: String, targetLanguage: String, audioFileURL: URL? = nil, audioData: Data? = nil) {
        self.requestId = UUID()
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.audioFileURL = audioFileURL
        self.audioData = audioData
        self.timestamp = Date()
    }
    
    var dictionary: [String: Any] {
        var dict: [String: Any] = [
            "requestId": requestId.uuidString,
            "sourceLanguage": sourceLanguage,
            "targetLanguage": targetLanguage,
            "timestamp": timestamp.timeIntervalSince1970
        ]
        
        if let audioData = audioData {
            dict["audioData"] = audioData
        }
        
        return dict
    }
    
    init?(from dictionary: [String: Any]) {
        guard let requestIdString = dictionary["requestId"] as? String,
              let requestId = UUID(uuidString: requestIdString),
              let sourceLanguage = dictionary["sourceLanguage"] as? String,
              let targetLanguage = dictionary["targetLanguage"] as? String,
              let timestampInterval = dictionary["timestamp"] as? TimeInterval else {
            return nil
        }
        
        self.requestId = requestId
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.audioData = dictionary["audioData"] as? Data
        self.audioFileURL = nil
        self.timestamp = Date(timeIntervalSince1970: timestampInterval)
    }
}