//
//  WatchSessionManager.swift
//  UniversalTranslator
//
//  Manages communication with Apple Watch app
//

import Foundation
import WatchConnectivity
import AVFoundation

class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()
    
    @Published var isWatchAppInstalled = false
    @Published var isPaired = false
    @Published var isReachable = false
    
    private var session: WCSession?
    private let translationService = TranslationService.shared
    private let creditsManager = CreditsManager.shared
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }
    }
    
    func activate() {
        session?.activate()
    }
    
    // MARK: - Sending Data to Watch
    
    func sendTranslationResponse(_ response: TranslationResponse) {
        guard let session = session, session.isReachable else {
            print("❌ iPhone: Watch not reachable")
            return
        }
        
        session.sendMessage(response.dictionary, replyHandler: nil) { error in
            print("❌ iPhone: Failed to send response: \(error)")
        }
        
        print("📤 iPhone: Sent translation response to Watch")
    }
    
    func updateCredits() {
        guard let session = session else { return }
        
        Task { @MainActor in
            let credits = creditsManager.remainingSeconds
            let context = ["credits": credits]
            
            do {
                try session.updateApplicationContext(context)
                print("💰 iPhone: Updated Watch credits: \(credits)")
            } catch {
                print("❌ iPhone: Failed to update credits: \(error)")
            }
        }
    }
    
    func syncLanguages(source: String, target: String) {
        guard let session = session else { return }
        
        let context = [
            "sourceLanguage": source,
            "targetLanguage": target
        ]
        
        do {
            try session.updateApplicationContext(context)
            print("🌐 iPhone: Synced languages to Watch: \(source) → \(target)")
        } catch {
            print("❌ iPhone: Failed to sync languages: \(error)")
        }
    }
    
    // MARK: - Processing Watch Requests
    
    private func processTranslationRequest(_ request: TranslationRequest, audioURL: URL?) {
        Task {
            do {
                var audioToProcess: URL
                
                // If audio URL provided, use it
                if let audioURL = audioURL {
                    audioToProcess = audioURL
                }
                // If audio data provided, save to temp file
                else if let audioData = request.audioData {
                    let tempURL = AudioConstants.temporaryAudioFileURL()
                    try audioData.write(to: tempURL)
                    audioToProcess = tempURL
                } else {
                    throw TranslationError.emptyText
                }
                
                print("🎙️ iPhone: Processing Watch audio: \(audioToProcess.lastPathComponent)")
                
                // Use existing iPhone pipeline
                // 1. Speech-to-text (local or server)
                let transcription = try await transcribeAudio(audioToProcess, language: request.sourceLanguage)
                
                print("📝 iPhone: Transcribed: \"\(transcription.prefix(50))...\"")
                
                // 2. Translation with audio
                let translationResult = try await translationService.translateWithAudio(
                    text: transcription,
                    from: request.sourceLanguage,
                    to: request.targetLanguage
                )
                
                print("🌐 iPhone: Translated: \"\(translationResult.translatedText.prefix(50))...\"")
                
                // 3. Create response
                let creditsRemaining = await MainActor.run { creditsManager.remainingSeconds }
                let response = TranslationResponse(
                    requestId: request.requestId,
                    originalText: transcription,
                    translatedText: translationResult.translatedText,
                    audioData: translationResult.audioData,
                    error: nil,
                    creditsRemaining: creditsRemaining
                )
                
                // 4. Send back to Watch
                sendTranslationResponse(response)
                
                // 5. Update credits
                updateCredits()
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: audioToProcess)
                
            } catch {
                print("❌ iPhone: Translation failed: \(error)")
                
                // Send error response
                let creditsRemaining = await MainActor.run { creditsManager.remainingSeconds }
                let errorResponse = TranslationResponse(
                    requestId: request.requestId,
                    originalText: "",
                    translatedText: "",
                    audioData: nil,
                    error: error.localizedDescription,
                    creditsRemaining: creditsRemaining
                )
                
                sendTranslationResponse(errorResponse)
            }
        }
    }
    
    private func transcribeAudio(_ audioURL: URL, language: String) async throws -> String {
        // Try local STT first
        let audioManager = AudioManager.shared
        
        do {
            return try await audioManager.transcribeAudio(audioURL, language: language)
        } catch {
            print("⚠️ iPhone: Local STT failed, using server")
            // Fall back to server STT
            return try await translationService.remoteSpeechToText(audioURL: audioURL, language: language)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ iPhone: Session activation failed: \(error)")
        } else {
            print("✅ iPhone: Session activated with state: \(activationState.rawValue)")
        }
        
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
        
        // Send initial data
        if session.isReachable {
            updateCredits()
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("⏸️ iPhone: Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("⏹️ iPhone: Session deactivated")
        // Re-activate session
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            print("⌚ iPhone: Watch state changed - Paired: \(session.isPaired), Installed: \(session.isWatchAppInstalled)")
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("📱 iPhone: Watch reachability changed: \(session.isReachable)")
        }
    }
    
    // MARK: - Receiving Messages
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedMessage(message, replyHandler: nil)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleReceivedMessage(message, replyHandler: replyHandler)
    }
    
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("📥 iPhone: Received file from Watch: \(file.fileURL.lastPathComponent)")
        
        // Process translation request from metadata
        if let request = TranslationRequest(from: file.metadata ?? [:]) {
            processTranslationRequest(request, audioURL: file.fileURL)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        print("📥 iPhone: Received message data: \(messageData.count) bytes")
    }
    
    // MARK: - Helper Methods
    
    private func handleReceivedMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        // Check for special actions
        if let action = message["action"] as? String {
            switch action {
            case "requestCredits":
                Task { @MainActor in
                    let credits = creditsManager.remainingSeconds
                    replyHandler?(["credits": credits])
                    print("💰 iPhone: Sent credits to Watch: \(credits)")
                }
                
            case "syncLanguages":
                // Get current languages from ContentView (you might need to store these in UserDefaults)
                let source = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "en"
                let target = UserDefaults.standard.string(forKey: "targetLanguage") ?? "es"
                replyHandler?(["sourceLanguage": source, "targetLanguage": target])
                print("🌐 iPhone: Sent languages to Watch: \(source) → \(target)")
                
            default:
                print("⚠️ iPhone: Unknown action: \(action)")
                replyHandler?(["status": "unknown"])
            }
        }
        // Check if it's a translation request
        else if let request = TranslationRequest(from: message) {
            print("📥 iPhone: Received translation request from Watch")
            processTranslationRequest(request, audioURL: nil)
            replyHandler?(["status": "processing"])
        } else {
            replyHandler?(["status": "error"])
        }
    }
}