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
    
    func sendTranslationRequest(_ request: TranslationRequest, completion: @escaping (Bool) -> Void, attempt: Int = 1) {
        guard let session = session else {
            print("❌ Watch: WCSession not available.")
            completion(false)
            return
        }

        guard session.isReachable else {
            print("❌ Watch: iPhone not reachable on attempt \(attempt).")
            if attempt < 3 {
                print("🔄 Watch: Retrying in 2 seconds...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.sendTranslationRequest(request, completion: completion, attempt: attempt + 1)
                }
            } else {
                completion(false)
            }
            return
        }
        
        pendingRequests[request.requestId] = { [weak self] response in
            print("🔄 Watch: Completion handler called for \(request.requestId)")
            DispatchQueue.main.async {
                self?.lastResponse = response
                print("✅ Watch: Response stored in lastResponse")
            }
        }
        
        if let audioURL = request.audioFileURL {
            let metadata = request.dictionary
            session.transferFile(audioURL, metadata: metadata)
            print("📤 Watch: Sending audio file to iPhone: \(audioURL.lastPathComponent)")
            completion(true)
        } else if let audioData = request.audioData, audioData.count < AudioConstants.maxChunkSize {
            session.sendMessage(request.dictionary, replyHandler: { _ in
                print("✅ Watch: Successfully sent audio data message.")
                completion(true)
            }) { error in
                print("❌ Watch: Failed to send message: \(error.localizedDescription)")
                if (error as? WCError)?.code == .notReachable, attempt < 3 {
                    print("🔄 Watch: iPhone became unreachable. Retrying in 2 seconds...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.sendTranslationRequest(request, completion: completion, attempt: attempt + 1)
                    }
                } else {
                    completion(false)
                }
            }
        } else {
            print("❌ Watch: No audio data to send or data too large for a message.")
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