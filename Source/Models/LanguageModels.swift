import Foundation

struct LanguageInfo {
    let code: String
    let name: String
    let nativeName: String
    let bcp47: String
}

struct Language: Codable {
    let code: String
    let name: String
    let nativeName: String
    let isSupported: Bool
}

struct SpeechRecognitionConfig {
    let locale: Locale
    let shouldReportPartialResults: Bool
    let requiresOnDeviceRecognition: Bool
    let contextualStrings: [String]
    let interactionIdentifier: String?
}