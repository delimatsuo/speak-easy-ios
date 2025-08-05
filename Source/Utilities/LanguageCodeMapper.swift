import Foundation

class LanguageCodeMapper {
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
    
    private static let supportedPairs: [(source: String, target: String)] = {
        let languages = Array(iso639Mapping.keys)
        var pairs: [(String, String)] = []
        
        for source in languages {
            for target in languages where source != target {
                pairs.append((source, target))
            }
        }
        
        return pairs
    }()
    
    static func validate(_ code: String) -> Bool {
        return iso639Mapping[code] != nil
    }
    
    static func getLanguageInfo(for code: String) -> LanguageInfo? {
        return iso639Mapping[code]
    }
    
    static func getAllSupportedLanguages() -> [Language] {
        return iso639Mapping.map { (code, info) in
            Language(
                code: code,
                name: info.name,
                nativeName: info.nativeName,
                isSupported: true
            )
        }
    }
    
    static func getBCP47Code(for iso639Code: String) -> String? {
        return iso639Mapping[iso639Code]?.bcp47
    }
    
    static func getISO639Code(from bcp47Code: String) -> String? {
        for (iso639, info) in iso639Mapping {
            if info.bcp47 == bcp47Code {
                return iso639
            }
        }
        return nil
    }
    
    static func autoDetect(from text: String) async -> String? {
        do {
            let detectedCode = try await GeminiAPIClient.shared.detectLanguage(text)
            return validate(detectedCode) ? detectedCode : nil
        } catch {
            print("Language detection failed: \(error)")
            return nil
        }
    }
    
    static func validatePair(source: String, target: String) -> Bool {
        return supportedPairs.contains { $0.source == source && $0.target == target }
    }
    
    static func getSupportedPairs() -> [(source: String, target: String)] {
        return supportedPairs
    }
    
    static func getPopularPairs() -> [(source: String, target: String)] {
        return [
            ("en", "es"), ("en", "fr"), ("en", "de"), ("en", "ja"), ("en", "zh"),
            ("es", "en"), ("fr", "en"), ("de", "en"), ("ja", "en"), ("zh", "en"),
            ("es", "fr"), ("fr", "de"), ("de", "it"), ("it", "pt"), ("pt", "es")
        ]
    }
    
    static func detectFromLocale() -> String {
        let currentLocale = Locale.current
        
        if let languageCode = currentLocale.language.languageCode?.identifier,
           validate(languageCode) {
            return languageCode
        }
        
        return "en"
    }
    
    static func getDisplayName(for code: String, in locale: Locale = Locale.current) -> String? {
        guard let languageInfo = iso639Mapping[code] else { return nil }
        
        if locale.language.languageCode?.identifier == code {
            return languageInfo.nativeName
        }
        
        return locale.localizedString(forLanguageCode: code) ?? languageInfo.name
    }
}