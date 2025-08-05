import Foundation

struct TTSRequest: Codable {
    let input: SynthesisInput
    let voice: VoiceSelectionParams
    let audioConfig: AudioConfig
    
    struct SynthesisInput: Codable {
        let text: String
    }
    
    struct VoiceSelectionParams: Codable {
        let languageCode: String
        let name: String?
        let ssmlGender: String
    }
    
    struct AudioConfig: Codable {
        let audioEncoding: String = "MP3"
        let speakingRate: Float
        let pitch: Float
        let volumeGainDb: Float
        let sampleRateHertz: Int = 24000
        let effectsProfileId: [String] = ["headphone-class-device"]
    }
    
    init(text: String, languageCode: String, voiceParams: VoiceParameters) {
        self.input = SynthesisInput(text: text)
        
        self.voice = VoiceSelectionParams(
            languageCode: languageCode,
            name: VoiceSelector.selectVoice(for: languageCode),
            ssmlGender: voiceParams.gender.rawValue
        )
        
        self.audioConfig = AudioConfig(
            speakingRate: voiceParams.speakingRate,
            pitch: voiceParams.pitch,
            volumeGainDb: voiceParams.volumeGainDb
        )
    }
}

struct TTSResponse: Codable {
    let audioContent: String
    let audioMetadata: AudioMetadata?
    
    struct AudioMetadata: Codable {
        let duration: TimeInterval
        let sampleRate: Int
        let encoding: String
        let channels: Int
    }
    
    func decodeAudio() throws -> Data {
        guard let audioData = Data(base64Encoded: audioContent) else {
            throw TTSError.invalidAudioData
        }
        return audioData
    }
    
    func saveToFile(url: URL) throws {
        let audioData = try decodeAudio()
        try audioData.write(to: url)
    }
}

struct VoiceParameters {
    let gender: Gender
    let speakingRate: Float
    let pitch: Float
    let volumeGainDb: Float
    
    enum Gender: String, Codable {
        case male = "MALE"
        case female = "FEMALE"
        case neutral = "NEUTRAL"
    }
    
    static let `default` = VoiceParameters(
        gender: .neutral,
        speakingRate: 1.0,
        pitch: 0.0,
        volumeGainDb: 0.0
    )
}