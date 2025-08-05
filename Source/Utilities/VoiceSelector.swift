import Foundation

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
        "ru": ["ru-RU-Wavenet-C", "ru-RU-Neural2-A", "ru-RU-Studio-D"],
        "ar": ["ar-XA-Wavenet-B", "ar-XA-Neural2-A", "ar-XA-Studio-A"],
        "hi": ["hi-IN-Wavenet-C", "hi-IN-Neural2-A", "hi-IN-Studio-A"],
        "nl": ["nl-NL-Wavenet-E", "nl-NL-Neural2-A", "nl-NL-Studio-A"],
        "sv": ["sv-SE-Wavenet-A", "sv-SE-Neural2-A", "sv-SE-Studio-A"],
        "pl": ["pl-PL-Wavenet-E", "pl-PL-Neural2-A", "pl-PL-Studio-A"]
    ]
    
    static func selectVoice(for languageCode: String) -> String? {
        let language = String(languageCode.prefix(2)).lowercased()
        let voices = voiceMapping[language] ?? []
        
        if let userPreferred = UserDefaults.standard.string(forKey: "voice_\(language)") {
            return userPreferred
        }
        
        return voices.first(where: { $0.contains("Neural2") }) ??
               voices.first(where: { $0.contains("Wavenet") }) ??
               voices.first
    }
    
    static func fallbackVoice(for languageCode: String) -> String {
        return "en-US-Neural2-J"
    }
    
    static func getAvailableVoices(for languageCode: String) -> [Voice] {
        let language = String(languageCode.prefix(2)).lowercased()
        let voiceNames = voiceMapping[language] ?? []
        
        return voiceNames.map { voiceName in
            Voice(
                name: voiceName,
                languageCode: languageCode,
                gender: extractGender(from: voiceName),
                quality: extractQuality(from: voiceName)
            )
        }
    }
    
    static func getAllAvailableVoices() -> [Voice] {
        var allVoices: [Voice] = []
        
        for (language, voiceNames) in voiceMapping {
            let languageCode = LanguageCodeMapper.getBCP47Code(for: language) ?? "\(language)-XX"
            
            for voiceName in voiceNames {
                let voice = Voice(
                    name: voiceName,
                    languageCode: languageCode,
                    gender: extractGender(from: voiceName),
                    quality: extractQuality(from: voiceName)
                )
                allVoices.append(voice)
            }
        }
        
        return allVoices
    }
    
    static func setPreferredVoice(_ voiceName: String, for languageCode: String) {
        let language = String(languageCode.prefix(2)).lowercased()
        UserDefaults.standard.set(voiceName, forKey: "voice_\(language)")
    }
    
    static func getPreferredVoice(for languageCode: String) -> String? {
        let language = String(languageCode.prefix(2)).lowercased()
        return UserDefaults.standard.string(forKey: "voice_\(language)")
    }
    
    static func validateVoice(_ voiceName: String, for languageCode: String) -> Bool {
        let availableVoices = getAvailableVoices(for: languageCode)
        return availableVoices.contains { $0.name == voiceName }
    }
    
    private static func extractGender(from voiceName: String) -> VoiceParameters.Gender {
        if voiceName.contains("-A") || voiceName.contains("-C") || voiceName.contains("-E") {
            return .female
        } else if voiceName.contains("-B") || voiceName.contains("-D") || voiceName.contains("-F") {
            return .male
        } else {
            return .neutral
        }
    }
    
    private static func extractQuality(from voiceName: String) -> Voice.Quality {
        if voiceName.contains("Neural2") {
            return .neural
        } else if voiceName.contains("Wavenet") {
            return .premium
        } else if voiceName.contains("Studio") {
            return .neural
        } else {
            return .standard
        }
    }
}