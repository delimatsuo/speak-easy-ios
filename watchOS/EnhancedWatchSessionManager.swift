//
//  EnhancedWatchSessionManager.swift
//  UniversalTranslator Watch App
//
//  Enhanced Watch connectivity with improved reliability, automatic reconnection,
//  message queuing, health checks, and error recovery mechanisms.
//

import Foundation
import WatchConnectivity
import Network
import Combine

// MARK: - Message Types

enum WatchMessageType: String, CaseIterable {
    case translationRequest = "translationRequest"
    case creditsUpdate = "creditsUpdate"
    case languageSync = "languageSync"
    case healthCheck = "healthCheck"
    case acknowledgment = "ack"
}

// MARK: - Connection State

enum WatchConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case error(String)
}

// MARK: - Queued Message

struct QueuedMessage {
    let id: UUID = UUID()
    let type: WatchMessageType
    let payload: [String: Any]
    let timestamp: Date = Date()
    let retryCount: Int
    let maxRetries: Int
    let completion: ((Bool) -> Void)?
    
    init(type: WatchMessageType, payload: [String: Any], maxRetries: Int = 3, completion: ((Bool) -> Void)? = nil) {
        self.type = type
        self.payload = payload
        self.retryCount = 0
        self.maxRetries = maxRetries
        self.completion = completion
    }
    
    func withIncrementedRetry() -> QueuedMessage {
        return QueuedMessage(type: type, payload: payload, maxRetries: maxRetries, completion: completion)
    }
}

// MARK: - Enhanced Watch Session Manager

class EnhancedWatchSessionManager: NSObject, ObservableObject {
    static let shared = EnhancedWatchSessionManager()
    
    // MARK: - Published Properties
    @Published private(set) var connectionState: WatchConnectionState = .disconnected
    @Published private(set) var isReachable = false
    @Published private(set) var creditsRemaining = 0
    @Published var lastResponse: TranslationResponse?
    @Published var sourceLanguage = "en"
    @Published var targetLanguage = "es"
    @Published private(set) var queuedMessagesCount = 0
    @Published private(set) var connectionQuality: ConnectionQuality = .unknown
    
    // MARK: - Private Properties
    private var session: WCSession?
    private var pendingRequests: [UUID: (TranslationResponse?) -> Void] = [:]
    private var messageQueue: [QueuedMessage] = []
    private var acknowledgments: [UUID: Date] = [:]
    
    // Connection Management
    private var reconnectionTimer: Timer?
    private var healthCheckTimer: Timer?
    private var messageTimeoutTimer: Timer?
    private var currentBackoffDelay: TimeInterval = 1.0
    private let maxBackoffDelay: TimeInterval = 32.0
    private let healthCheckInterval: TimeInterval = 30.0
    
    // Network Monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "watch.network.monitor")
    
    // Quality Metrics
    private var lastHealthCheckTime: Date?
    private var healthCheckResponses: [TimeInterval] = []
    private let maxHealthCheckHistory = 10
    
    enum ConnectionQuality {
        case unknown
        case poor
        case fair
        case good
        case excellent
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        startNetworkMonitoring()
        startHealthChecks()
        setupMessageTimeoutMonitoring()
        print("🚀 Enhanced Watch Session Manager initialized")
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup Methods
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else {
            connectionState = .error("Watch Connectivity not supported")
            print("❌ Enhanced Watch: WCSession not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        activate()
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkPathUpdate(path)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    private func startHealthChecks() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }
    
    private func setupMessageTimeoutMonitoring() {
        messageTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkMessageTimeouts()
        }
    }
    
    // MARK: - Public Interface
    
    func activate() {
        guard let session = session else { return }
        
        connectionState = .connecting
        print("🔄 Enhanced Watch: Activating session...")
        
        if session.activationState != .activated {
            session.activate()
        } else {
            handleSuccessfulConnection()
        }
    }
    
    func sendTranslationRequest(_ request: TranslationRequest, completion: @escaping (Bool) -> Void) {
        let message = QueuedMessage(
            type: .translationRequest,
            payload: request.dictionary,
            maxRetries: 5,
            completion: completion
        )
        
        // Store completion handler
        pendingRequests[request.requestId] = { [weak self] response in
            DispatchQueue.main.async {
                self?.lastResponse = response
                completion(response != nil)
            }
        }
        
        enqueueMessage(message)
    }
    
    func requestCreditsUpdate(completion: ((Bool) -> Void)? = nil) {
        let message = QueuedMessage(
            type: .creditsUpdate,
            payload: ["action": "requestCredits"],
            completion: completion
        )
        enqueueMessage(message)
    }
    
    func syncLanguages(source: String? = nil, target: String? = nil, completion: ((Bool) -> Void)? = nil) {
        let message = QueuedMessage(
            type: .languageSync,
            payload: ["action": "syncLanguages"],
            completion: completion
        )
        enqueueMessage(message)
    }
    
    func forceReconnection() {
        print("🔄 Enhanced Watch: Forcing reconnection...")
        connectionState = .reconnecting
        currentBackoffDelay = 1.0
        attemptReconnection()
    }
    
    func clearMessageQueue() {
        messageQueue.removeAll()
        queuedMessagesCount = 0
        print("🗑️ Enhanced Watch: Message queue cleared")
    }
    
    // MARK: - Private Methods
    
    private func enqueueMessage(_ message: QueuedMessage) {
        messageQueue.append(message)
        queuedMessagesCount = messageQueue.count
        print("📝 Enhanced Watch: Queued message type: \(message.type.rawValue), Queue size: \(messageQueue.count)")
        
        // Try to process queue immediately if connected
        processMessageQueue()
    }
    
    private func processMessageQueue() {
        guard isReachable, !messageQueue.isEmpty else { return }
        
        let messagesToProcess = Array(messageQueue.prefix(3)) // Process up to 3 messages at once
        
        for message in messagesToProcess {
            sendQueuedMessage(message)
        }
    }
    
    private func sendQueuedMessage(_ message: QueuedMessage) {
        guard let session = session, session.isReachable else {
            print("⚠️ Enhanced Watch: Session not reachable when trying to send queued message")
            return
        }
        
        print("📤 Enhanced Watch: Sending message type: \(message.type.rawValue)")
        
        // Add acknowledgment tracking
        var payload = message.payload
        payload["messageId"] = message.id.uuidString
        payload["requiresAck"] = true
        
        session.sendMessage(payload, replyHandler: { [weak self] reply in
            self?.handleMessageReply(messageId: message.id, reply: reply)
        }, errorHandler: { [weak self] error in
            self?.handleMessageError(message: message, error: error)
        })
        
        // Remove from queue
        if let index = messageQueue.firstIndex(where: { $0.id == message.id }) {
            messageQueue.remove(at: index)
            queuedMessagesCount = messageQueue.count
        }
    }
    
    private func handleMessageReply(messageId: UUID, reply: [String: Any]) {
        print("✅ Enhanced Watch: Received reply for message \(messageId)")
        
        // Process specific reply types
        if let credits = reply["credits"] as? Int {
            creditsRemaining = credits
        }
        
        if let source = reply["sourceLanguage"] as? String,
           let target = reply["targetLanguage"] as? String {
            sourceLanguage = source
            targetLanguage = target
        }
        
        // Handle translation responses
        if let response = TranslationResponse(from: reply) {
            if let handler = pendingRequests[response.requestId] {
                handler(response)
                pendingRequests.removeValue(forKey: response.requestId)
            }
        }
    }
    
    private func handleMessageError(message: QueuedMessage, error: Error) {
        print("❌ Enhanced Watch: Message failed: \(error.localizedDescription)")
        
        if message.retryCount < message.maxRetries {
            let retryMessage = message.withIncrementedRetry()
            print("🔄 Enhanced Watch: Retrying message (attempt \(retryMessage.retryCount + 1)/\(retryMessage.maxRetries))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(retryMessage.retryCount)) {
                self.enqueueMessage(retryMessage)
            }
        } else {
            print("💥 Enhanced Watch: Message failed permanently after \(message.maxRetries) retries")
            message.completion?(false)
        }
    }
    
    private func performHealthCheck() {
        guard isReachable else { return }
        
        let startTime = Date()
        lastHealthCheckTime = startTime
        
        let healthMessage = QueuedMessage(
            type: .healthCheck,
            payload: ["timestamp": startTime.timeIntervalSince1970],
            maxRetries: 1
        ) { [weak self] success in
            if success {
                let responseTime = Date().timeIntervalSince(startTime)
                self?.updateConnectionQuality(responseTime: responseTime)
            } else {
                self?.handleHealthCheckFailure()
            }
        }
        
        sendQueuedMessage(healthMessage)
    }
    
    private func updateConnectionQuality(responseTime: TimeInterval) {
        healthCheckResponses.append(responseTime)
        if healthCheckResponses.count > maxHealthCheckHistory {
            healthCheckResponses.removeFirst()
        }
        
        let averageResponse = healthCheckResponses.reduce(0, +) / Double(healthCheckResponses.count)
        
        connectionQuality = {
            switch averageResponse {
            case 0..<0.1: return .excellent
            case 0.1..<0.3: return .good
            case 0.3..<0.8: return .fair
            case 0.8..<2.0: return .poor
            default: return .poor
            }
        }()
        
        print("📊 Enhanced Watch: Connection quality: \(connectionQuality), avg response: \(String(format: "%.3f", averageResponse))s")
    }
    
    private func handleHealthCheckFailure() {
        print("💔 Enhanced Watch: Health check failed")
        connectionQuality = .poor
        
        if isReachable {
            // Connection might be stale, attempt reconnection
            attemptReconnection()
        }
    }
    
    private func checkMessageTimeouts() {
        let now = Date()
        let timeoutInterval: TimeInterval = 30.0
        
        let timedOutMessages = messageQueue.filter { now.timeIntervalSince($0.timestamp) > timeoutInterval }
        
        for message in timedOutMessages {
            print("⏰ Enhanced Watch: Message timed out: \(message.type.rawValue)")
            handleMessageError(message: message, error: NSError(domain: "WatchConnectivity", code: -1, userInfo: [NSLocalizedDescriptionKey: "Message timeout"]))
        }
    }
    
    private func attemptReconnection() {
        guard connectionState != .connecting else { return }
        
        connectionState = .reconnecting
        print("🔄 Enhanced Watch: Attempting reconnection with backoff: \(currentBackoffDelay)s")
        
        reconnectionTimer?.invalidate()
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: currentBackoffDelay, repeats: false) { [weak self] _ in
            self?.activate()
        }
        
        // Exponential backoff
        currentBackoffDelay = min(currentBackoffDelay * 2, maxBackoffDelay)
    }
    
    private func handleSuccessfulConnection() {
        connectionState = .connected
        isReachable = true
        currentBackoffDelay = 1.0 // Reset backoff
        reconnectionTimer?.invalidate()
        
        print("✅ Enhanced Watch: Successfully connected")
        
        // Process any queued messages
        processMessageQueue()
        
        // Request initial data sync
        requestCreditsUpdate()
        syncLanguages()
    }
    
    private func handleNetworkPathUpdate(_ path: NWPath) {
        let isNetworkAvailable = path.status == .satisfied
        print("🌐 Enhanced Watch: Network status changed: \(isNetworkAvailable ? "Available" : "Unavailable")")
        
        if isNetworkAvailable && !isReachable {
            // Network became available, try to reconnect
            attemptReconnection()
        }
    }
    
    private func cleanup() {
        reconnectionTimer?.invalidate()
        healthCheckTimer?.invalidate()
        messageTimeoutTimer?.invalidate()
        networkMonitor.cancel()
        session?.delegate = nil
        print("🧹 Enhanced Watch: Cleanup completed")
    }
}

// MARK: - WCSessionDelegate

extension EnhancedWatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error = error {
                print("❌ Enhanced Watch: Session activation failed: \(error.localizedDescription)")
                self?.connectionState = .error(error.localizedDescription)
            } else {
                print("✅ Enhanced Watch: Session activated with state: \(activationState.rawValue)")
                self?.handleSuccessfulConnection()
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let wasReachable = self.isReachable
            self.isReachable = session.isReachable
            
            print("📱 Enhanced Watch: Reachability changed from \(wasReachable) to \(session.isReachable)")
            
            if session.isReachable {
                self.handleSuccessfulConnection()
            } else {
                self.connectionState = .disconnected
                // Start reconnection attempts
                self.attemptReconnection()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleReceivedMessage(message)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["status": "received", "timestamp": Date().timeIntervalSince1970])
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async { [weak self] in
            // Handle app context updates
            if let credits = applicationContext["credits"] as? Int {
                self?.creditsRemaining = credits
            }
            
            if let source = applicationContext["sourceLanguage"] as? String,
               let target = applicationContext["targetLanguage"] as? String {
                self?.sourceLanguage = source
                self?.targetLanguage = target
            }
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        print("📥 Enhanced Watch: Received message: \(message.keys.joined(separator: ", "))")
        
        // Handle acknowledgments
        if let messageId = message["messageId"] as? String,
           let requiresAck = message["requiresAck"] as? Bool,
           requiresAck {
            acknowledgments[UUID(uuidString: messageId) ?? UUID()] = Date()
        }
        
        // Process translation responses
        if let response = TranslationResponse(from: message) {
            DispatchQueue.main.async { [weak self] in
                if let handler = self?.pendingRequests[response.requestId] {
                    handler(response)
                    self?.pendingRequests.removeValue(forKey: response.requestId)
                }
                self?.lastResponse = response
                self?.creditsRemaining = response.creditsRemaining
            }
        }
        
        // Handle other message types
        if let action = message["action"] as? String {
            handleAction(action, message: message)
        }
    }
    
    private func handleAction(_ action: String, message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            switch action {
            case "creditsUpdate":
                if let credits = message["credits"] as? Int {
                    self?.creditsRemaining = credits
                }
            case "languagesUpdate":
                if let source = message["sourceLanguage"] as? String,
                   let target = message["targetLanguage"] as? String {
                    self?.sourceLanguage = source
                    self?.targetLanguage = target
                }
            case "healthCheckResponse":
                // Health check response received
                if let timestamp = message["originalTimestamp"] as? TimeInterval {
                    let responseTime = Date().timeIntervalSince1970 - timestamp
                    self?.updateConnectionQuality(responseTime: responseTime)
                }
            default:
                print("⚠️ Enhanced Watch: Unknown action: \(action)")
            }
        }
    }
}
