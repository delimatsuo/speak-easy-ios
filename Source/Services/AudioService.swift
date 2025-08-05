import Foundation
import AVFoundation

class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(text: String, language: Language) async throws {
        guard !text.isEmpty else { return }
        
        await MainActor.run {
            isSpeaking = true
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.code)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.synthesizer.speak(utterance)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                continuation.resume()
            }
        }
    }
    
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

extension AudioService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}