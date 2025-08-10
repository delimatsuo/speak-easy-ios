import Foundation

struct Language: Identifiable, Codable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let nativeName: String
    let flag: String
    let isOfflineAvailable: Bool
    
    init(code: String, name: String, nativeName: String, flag: String, isOfflineAvailable: Bool = false) {
        self.code = code
        self.name = name
        self.nativeName = nativeName
        self.flag = flag
        self.isOfflineAvailable = isOfflineAvailable
    }
    
    static let supportedLanguages: [Language] = [
        Language(code: "en", name: "English", nativeName: "English", flag: "🇺🇸", isOfflineAvailable: true),
        Language(code: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸", isOfflineAvailable: true),
        Language(code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷"),
        Language(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪"),
        Language(code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵"),
        Language(code: "zh", name: "Chinese (Simplified)", nativeName: "中文", flag: "🇨🇳"),
        Language(code: "zh-TW", name: "Chinese (Traditional)", nativeName: "繁體中文", flag: "🇹🇼"),
        Language(code: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦"),
        Language(code: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
        Language(code: "pt", name: "Portuguese", nativeName: "Português", flag: "🇧🇷"),
        Language(code: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹"),
        Language(code: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
        Language(code: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳")
    ]
    
    static let defaultSource = supportedLanguages[0] // English
    static let defaultTarget = supportedLanguages[1] // Spanish
}