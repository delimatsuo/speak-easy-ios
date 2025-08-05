import Foundation

protocol TranslationService {
    func translate(text: String, from: String, to: String) async throws -> Translation
    func detectLanguage(text: String) async throws -> String
    func getSupportedLanguages() -> [Language]
    func validateLanguagePair(source: String, target: String) -> Bool
}