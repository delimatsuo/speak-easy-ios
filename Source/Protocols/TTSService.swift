import Foundation

protocol TTSService {
    func synthesize(text: String, language: String, voice: VoiceParameters?) async throws -> Data
    func getAvailableVoices(for language: String) -> [Voice]
    func preloadVoice(_ voice: Voice) async throws
}

struct Voice: Codable {
    let name: String
    let languageCode: String
    let gender: VoiceParameters.Gender
    let quality: Quality
    
    enum Quality: String, Codable {
        case standard = "STANDARD"
        case premium = "PREMIUM"
        case neural = "NEURAL"
    }
}