//
//  WatchConnectivityManager.swift
//  UniversalTranslator Watch App
//
//  Manages communication with paired iPhone
//

import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable = false
    @Published var creditsRemaining = 0
    @Published var lastResponse: TranslationResponse?
    @Published var sourceLanguage = "en"
    @Published var targetLanguage = "es"
    
    private var session: WCSession?
    private var pendingRequests: [UUID: (TranslationResponse?) -> Void] = [:]
    
    private override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
        }
    }
    
    func activate() {
        guard let session = session else {
            print("❌ Watch: WCSession not supported")
            return
        }
        
        if session.activationState == .notActivated {
            print("🔄 Watch: Activating WCSession...")
            session.activate()
        } else {
            print("✅ Watch: WCSession already activated with state: \(session.activationState.rawValue)")
        }
    }
    
    // MARK: - Sending Requests
    
    func sendTranslationRequest(_ request: TranslationRequest, completion: @escaping (Bool) -> Void) {
        guard let session = session, session.isReachable else {
            print("❌ Watch: iPhone not reachable")
            completion(false)
            return
        }
        
        // Store completion handler with better logging
        pendingRequests[request.requestId] = { [weak self] response in
            print("🔄 Watch: Completion handler called for \(request.requestId)")
            print("📊 Watch: Response details - Has response: \(response != nil), Error: \(response?.error ?? "none")")
            DispatchQueue.main.async {
                self?.lastResponse = response
                print("✅ Watch: Response stored in lastResponse")
            }
        }
        
        // If we have audio file, use file transfer
        if let audioURL = request.audioFileURL {
            let metadata = request.dictionary
            session.transferFile(audioURL, metadata: metadata)
            print("📤 Watch: Sending audio file to iPhone: \(audioURL.lastPathComponent)")
            completion(true)
        }
        // For small audio data, use message
        else if let audioData = request.audioData, audioData.count < AudioConstants.maxChunkSize {
            session.sendMessage(request.dictionary, replyHandler: nil) { error in
                print("❌ Watch: Failed to send message: \(error)")
                completion(false)
            }
            print("📤 Watch: Sending audio data to iPhone: \(audioData.count) bytes")
            completion(true)
        }
        // Fallback for edge cases
        else {
            print("❌ Watch: No audio data to send")
            completion(false)
        }
    }
    
    func requestCreditsUpdate() {
        guard let session = session, session.isReachable else { return }
        
        let message = ["action": "requestCredits"]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            if let credits = reply["credits"] as? Int {
                DispatchQueue.main.async {
                    self?.creditsRemaining = credits
                    print("💰 Watch: Credits updated: \(credits)")
                }
            }
        }, errorHandler: { error in
            print("❌ Watch: Failed to request credits: \(error)")
        })
    }
    
    func syncLanguages() {
        guard let session = session, session.isReachable else { return }
        
        let message = ["action": "syncLanguages"]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            if let source = reply["sourceLanguage"] as? String,
               let target = reply["targetLanguage"] as? String {
                DispatchQueue.main.async {
                    self?.sourceLanguage = source
                    self?.targetLanguage = target
                    print("🌐 Watch: Languages synced: \(source) → \(target)")
                }
            }
        }, errorHandler: { error in
            print("❌ Watch: Failed to sync languages: \(error)")
        })
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ Watch: Session activation failed: \(error)")
        } else {
            print("✅ Watch: Session activated with state: \(activationState.rawValue)")
            DispatchQueue.main.async {
                self.isReachable = session.isReachable
            }
            
            // Request initial data sync
            requestCreditsUpdate()
            syncLanguages()
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            print("📱 Watch: iPhone reachability changed: \(session.isReachable)")
        }
        
        if session.isReachable {
            requestCreditsUpdate()
            syncLanguages()
        }
    }
    
    // MARK: - Receiving Data
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "received"])
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        // Handle binary data if needed
        print("📥 Watch: Received message data: \(messageData.count) bytes")
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // Handle app context updates (credits, languages)
        if let credits = applicationContext["credits"] as? Int {
            DispatchQueue.main.async {
                self.creditsRemaining = credits
            }
        }
        
        if let source = applicationContext["sourceLanguage"] as? String,
           let target = applicationContext["targetLanguage"] as? String {
            DispatchQueue.main.async {
                self.sourceLanguage = source
                self.targetLanguage = target
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        // Check if it's a translation response
        if let response = TranslationResponse(from: message) {
            print("📥 Watch: Received translation response for request: \(response.requestId)")
            
            // Call pending completion handler
            if let handler = pendingRequests[response.requestId] {
                handler(response)
                pendingRequests.removeValue(forKey: response.requestId)
            }
            
            // Update published response
            DispatchQueue.main.async {
                self.lastResponse = response
                self.creditsRemaining = response.creditsRemaining
            }
        }
        // Handle other message types
        else if let action = message["action"] as? String {
            switch action {
            case "creditsUpdate":
                if let credits = message["credits"] as? Int {
                    DispatchQueue.main.async {
                        self.creditsRemaining = credits
                    }
                }
            case "languagesUpdate":
                if let source = message["sourceLanguage"] as? String,
                   let target = message["targetLanguage"] as? String {
                    DispatchQueue.main.async {
                        self.sourceLanguage = source
                        self.targetLanguage = target
                    }
                }
            default:
                print("⚠️ Watch: Unknown action: \(action)")
            }
        }
    }
}