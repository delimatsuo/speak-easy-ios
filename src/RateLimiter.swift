//
//  RateLimiter.swift
//  UniversalTranslator
//
//  Advanced rate limiting service with sliding window, burst handling,
//  concurrent request management, and adaptive throttling.
//

import Foundation
import Combine

// MARK: - Rate Limiting Errors

enum RateLimitError: Error, LocalizedError {
    case rateLimitExceeded
    case dailyQuotaExceeded
    case suspiciousActivity
    case tooManyRequests
    case blacklisted
    
    var errorDescription: String? {
        switch self {
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .dailyQuotaExceeded:
            return "Daily quota exceeded. Resets at midnight UTC."
        case .suspiciousActivity:
            return "Suspicious activity detected. Account temporarily restricted."
        case .tooManyRequests:
            return "Too many requests in a short period."
        case .blacklisted:
            return "Access denied."
        }
    }
}

// MARK: - Rate Limit Configuration

struct RateLimitConfig {
    let requestsPerMinute: Int
    let requestsPerHour: Int
    let requestsPerDay: Int
    let burstAllowance: Int
    let windowSize: TimeInterval
    let suspiciousThreshold: Int
    let blacklistDuration: TimeInterval
    
    static let `default` = RateLimitConfig(
        requestsPerMinute: 60,
        requestsPerHour: 1000,
        requestsPerDay: 10000,
        burstAllowance: 10,
        windowSize: 60.0,
        suspiciousThreshold: 100,
        blacklistDuration: 3600.0
    )
    
    static let premium = RateLimitConfig(
        requestsPerMinute: 120,
        requestsPerHour: 5000,
        requestsPerDay: 50000,
        burstAllowance: 20,
        windowSize: 60.0,
        suspiciousThreshold: 200,
        blacklistDuration: 1800.0
    )
}

// MARK: - Request Record

struct RequestRecord {
    let timestamp: Date
    let identifier: String
    let endpoint: String?
    let userAgent: String?
    let ipAddress: String?
    
    init(identifier: String, endpoint: String? = nil, userAgent: String? = nil, ipAddress: String? = nil) {
        self.timestamp = Date()
        self.identifier = identifier
        self.endpoint = endpoint
        self.userAgent = userAgent
        self.ipAddress = ipAddress
    }
}

// MARK: - Rate Limit Status

struct RateLimitStatus {
    let identifier: String
    let requestsInLastMinute: Int
    let requestsInLastHour: Int
    let requestsInLastDay: Int
    let remainingRequests: Int
    let resetTime: Date
    let isBlacklisted: Bool
    let burstTokens: Int
}

// MARK: - Rate Limiter

class RateLimiter: ObservableObject {
    static let shared = RateLimiter()
    
    // MARK: - Configuration
    private var config: RateLimitConfig
    private let queue = DispatchQueue(label: "rate-limiter", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Storage
    private var requestHistory: [String: [RequestRecord]] = [:]
    private var blacklist: [String: Date] = [:]
    private var burstTokens: [String: Int] = [:]
    private var suspiciousActivity: [String: Date] = [:]
    
    // MARK: - Monitoring
    @Published private(set) var totalRequestsToday = 0
    @Published private(set) var activeUsers = 0
    @Published private(set) var blockedRequests = 0
    @Published private(set) var suspiciousActivities = 0
    
    // Cleanup timer
    private var cleanupTimer: Timer?
    
    // MARK: - Initialization
    
    private init(config: RateLimitConfig = .default) {
        self.config = config
        setupCleanupTimer()
        initializeBurstTokens()
    }
    
    deinit {
        cleanupTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    /// Check if request is allowed for identifier
    func isRequestAllowed(for identifier: String, endpoint: String? = nil) -> Bool {
        return queue.sync {
            checkRateLimit(identifier: identifier, endpoint: endpoint)
        }
    }
    
    /// Record a request (call after successful rate limit check)
    func recordRequest(for identifier: String, endpoint: String? = nil, userAgent: String? = nil, ipAddress: String? = nil) {
        queue.async(flags: .barrier) {
            let record = RequestRecord(
                identifier: identifier,
                endpoint: endpoint,
                userAgent: userAgent,
                ipAddress: ipAddress
            )
            
            if self.requestHistory[identifier] == nil {
                self.requestHistory[identifier] = []
            }
            self.requestHistory[identifier]?.append(record)
            
            // Update metrics
            DispatchQueue.main.async {
                self.updateMetrics()
            }
        }
    }
    
    /// Get current rate limit status for identifier
    func getRateLimitStatus(for identifier: String) -> RateLimitStatus {
        return queue.sync {
            calculateRateLimitStatus(for: identifier)
        }
    }
    
    /// Check if identifier is blacklisted
    func isBlacklisted(_ identifier: String) -> Bool {
        return queue.sync {
            checkBlacklist(identifier)
        }
    }
    
    /// Manually blacklist an identifier
    func blacklist(_ identifier: String, duration: TimeInterval? = nil) {
        queue.async(flags: .barrier) {
            let blacklistUntil = Date().addingTimeInterval(duration ?? self.config.blacklistDuration)
            self.blacklist[identifier] = blacklistUntil
            
            DispatchQueue.main.async {
                self.blockedRequests += 1
            }
        }
    }
    
    /// Remove identifier from blacklist
    func removeFromBlacklist(_ identifier: String) {
        queue.async(flags: .barrier) {
            self.blacklist.removeValue(forKey: identifier)
        }
    }
    
    /// Update rate limit configuration
    func updateConfig(_ newConfig: RateLimitConfig) {
        queue.async(flags: .barrier) {
            self.config = newConfig
            self.initializeBurstTokens()
        }
    }
    
    /// Reset rate limits for identifier
    func resetRateLimit(for identifier: String) {
        queue.async(flags: .barrier) {
            self.requestHistory.removeValue(forKey: identifier)
            self.burstTokens[identifier] = self.config.burstAllowance
            self.suspiciousActivity.removeValue(forKey: identifier)
        }
    }
    
    /// Get all rate limit statuses (for admin/monitoring)
    func getAllRateLimitStatuses() -> [RateLimitStatus] {
        return queue.sync {
            requestHistory.keys.map { identifier in
                calculateRateLimitStatus(for: identifier)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func checkRateLimit(identifier: String, endpoint: String?) -> Bool {
        // Check blacklist first
        if checkBlacklist(identifier) {
            return false
        }
        
        // Get current request counts
        let now = Date()
        let history = requestHistory[identifier] ?? []
        
        let requestsInLastMinute = countRequests(in: history, since: now.addingTimeInterval(-60))
        let requestsInLastHour = countRequests(in: history, since: now.addingTimeInterval(-3600))
        let requestsInLastDay = countRequests(in: history, since: now.addingTimeInterval(-86400))
        
        // Check daily quota
        if requestsInLastDay >= config.requestsPerDay {
            detectSuspiciousActivity(identifier: identifier)
            return false
        }
        
        // Check hourly limit
        if requestsInLastHour >= config.requestsPerHour {
            return false
        }
        
        // Check minute limit with burst allowance
        if requestsInLastMinute >= config.requestsPerMinute {
            // Try to use burst tokens
            let currentTokens = burstTokens[identifier] ?? config.burstAllowance
            if currentTokens > 0 {
                burstTokens[identifier] = currentTokens - 1
                return true
            } else {
                return false
            }
        }
        
        // Check for suspicious activity patterns
        if detectSuspiciousActivity(identifier: identifier) {
            return false
        }
        
        return true
    }
    
    private func checkBlacklist(_ identifier: String) -> Bool {
        guard let blacklistUntil = blacklist[identifier] else {
            return false
        }
        
        if Date() > blacklistUntil {
            // Blacklist expired, remove it
            blacklist.removeValue(forKey: identifier)
            return false
        }
        
        return true
    }
    
    private func countRequests(in history: [RequestRecord], since date: Date) -> Int {
        return history.filter { $0.timestamp >= date }.count
    }
    
    private func calculateRateLimitStatus(for identifier: String) -> RateLimitStatus {
        let now = Date()
        let history = requestHistory[identifier] ?? []\n        \n        let requestsInLastMinute = countRequests(in: history, since: now.addingTimeInterval(-60))\n        let requestsInLastHour = countRequests(in: history, since: now.addingTimeInterval(-3600))\n        let requestsInLastDay = countRequests(in: history, since: now.addingTimeInterval(-86400))\n        \n        let remainingMinute = max(0, config.requestsPerMinute - requestsInLastMinute)\n        let remainingHour = max(0, config.requestsPerHour - requestsInLastHour)\n        let remainingDay = max(0, config.requestsPerDay - requestsInLastDay)\n        \n        let remainingRequests = min(remainingMinute, min(remainingHour, remainingDay))\n        \n        // Calculate next reset time (next minute boundary)\n        let calendar = Calendar.current\n        let nextMinute = calendar.dateInterval(of: .minute, for: now)?.end ?? now.addingTimeInterval(60)\n        \n        return RateLimitStatus(\n            identifier: identifier,\n            requestsInLastMinute: requestsInLastMinute,\n            requestsInLastHour: requestsInLastHour,\n            requestsInLastDay: requestsInLastDay,\n            remainingRequests: remainingRequests,\n            resetTime: nextMinute,\n            isBlacklisted: checkBlacklist(identifier),\n            burstTokens: burstTokens[identifier] ?? config.burstAllowance\n        )\n    }\n    \n    private func detectSuspiciousActivity(identifier: String) -> Bool {\n        let now = Date()\n        let history = requestHistory[identifier] ?? []\n        \n        // Check for burst of requests in short time\n        let recentRequests = countRequests(in: history, since: now.addingTimeInterval(-10)) // Last 10 seconds\n        \n        if recentRequests >= config.suspiciousThreshold / 10 { // Scaled threshold for 10 seconds\n            suspiciousActivity[identifier] = now\n            blacklist(identifier)\n            \n            DispatchQueue.main.async {\n                self.suspiciousActivities += 1\n            }\n            \n            return true\n        }\n        \n        // Check for pattern of requests at exact intervals (bot-like behavior)\n        if history.count >= 5 {\n            let lastFive = Array(history.suffix(5))\n            let intervals = zip(lastFive.dropFirst(), lastFive.dropLast()).map {\n                $0.0.timestamp.timeIntervalSince($0.1.timestamp)\n            }\n            \n            // If all intervals are very similar (within 0.1 seconds), it's suspicious\n            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)\n            let isUniform = intervals.allSatisfy { abs($0 - avgInterval) < 0.1 }\n            \n            if isUniform && avgInterval < 1.0 { // Very fast, uniform requests\n                suspiciousActivity[identifier] = now\n                blacklist(identifier)\n                \n                DispatchQueue.main.async {\n                    self.suspiciousActivities += 1\n                }\n                \n                return true\n            }\n        }\n        \n        return false\n    }\n    \n    private func initializeBurstTokens() {\n        // Replenish burst tokens for all users\n        for identifier in requestHistory.keys {\n            burstTokens[identifier] = config.burstAllowance\n        }\n    }\n    \n    private func setupCleanupTimer() {\n        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in\n            self?.performCleanup()\n        }\n    }\n    \n    private func performCleanup() {\n        queue.async(flags: .barrier) {\n            let now = Date()\n            let dayAgo = now.addingTimeInterval(-86400)\n            \n            // Clean old request history\n            for identifier in self.requestHistory.keys {\n                self.requestHistory[identifier] = self.requestHistory[identifier]?.filter { $0.timestamp > dayAgo }\n                if self.requestHistory[identifier]?.isEmpty == true {\n                    self.requestHistory.removeValue(forKey: identifier)\n                }\n            }\n            \n            // Clean expired blacklist entries\n            self.blacklist = self.blacklist.filter { $0.value > now }\n            \n            // Clean old suspicious activity records\n            let hourAgo = now.addingTimeInterval(-3600)\n            self.suspiciousActivity = self.suspiciousActivity.filter { $0.value > hourAgo }\n            \n            // Replenish burst tokens\n            self.initializeBurstTokens()\n            \n            DispatchQueue.main.async {\n                self.updateMetrics()\n            }\n        }\n    }\n    \n    private func updateMetrics() {\n        let now = Date()\n        let dayAgo = now.addingTimeInterval(-86400)\n        \n        totalRequestsToday = requestHistory.values.flatMap { $0 }\n            .filter { $0.timestamp > dayAgo }\n            .count\n        \n        activeUsers = requestHistory.keys.count\n        \n        // blocked requests are tracked when they happen\n        // suspicious activities are tracked when they happen\n    }\n}\n\n// MARK: - Rate Limiter Extensions\n\nextension RateLimiter {\n    /// Convenience method for API endpoints\n    func checkAPIRateLimit(userID: String, endpoint: String, request: URLRequest) -> Bool {\n        let identifier = \"api:\\(userID)\"\n        let userAgent = request.value(forHTTPHeaderField: \"User-Agent\")\n        \n        if isRequestAllowed(for: identifier, endpoint: endpoint) {\n            recordRequest(for: identifier, endpoint: endpoint, userAgent: userAgent)\n            return true\n        }\n        return false\n    }\n    \n    /// Rate limit based on IP address\n    func checkIPRateLimit(_ ipAddress: String, endpoint: String?) -> Bool {\n        let identifier = \"ip:\\(ipAddress)\"\n        \n        if isRequestAllowed(for: identifier, endpoint: endpoint) {\n            recordRequest(for: identifier, endpoint: endpoint, ipAddress: ipAddress)\n            return true\n        }\n        return false\n    }\n    \n    /// Combined user and IP rate limiting\n    func checkCombinedRateLimit(userID: String?, ipAddress: String, endpoint: String, request: URLRequest) -> Bool {\n        // Check IP rate limit first\n        if !checkIPRateLimit(ipAddress, endpoint: endpoint) {\n            return false\n        }\n        \n        // If user is authenticated, check user rate limit too\n        if let userID = userID {\n            return checkAPIRateLimit(userID: userID, endpoint: endpoint, request: request)\n        }\n        \n        return true\n    }\n}\n\n// MARK: - Concurrent Request Handler\n\nclass ConcurrentRateLimitHandler {\n    private let rateLimiter: RateLimiter\n    private let semaphore: DispatchSemaphore\n    private let queue = DispatchQueue(label: \"concurrent-rate-limit\", attributes: .concurrent)\n    \n    init(rateLimiter: RateLimiter = .shared, maxConcurrentRequests: Int = 10) {\n        self.rateLimiter = rateLimiter\n        self.semaphore = DispatchSemaphore(value: maxConcurrentRequests)\n    }\n    \n    func performRequest<T>(\n        identifier: String,\n        endpoint: String? = nil,\n        request: @escaping () async throws -> T\n    ) async throws -> T {\n        return try await withCheckedThrowingContinuation { continuation in\n            queue.async {\n                // Wait for available slot\n                self.semaphore.wait()\n                \n                defer {\n                    self.semaphore.signal()\n                }\n                \n                // Check rate limit\n                if !self.rateLimiter.isRequestAllowed(for: identifier, endpoint: endpoint) {\n                    continuation.resume(throwing: RateLimitError.rateLimitExceeded)\n                    return\n                }\n                \n                // Record the request\n                self.rateLimiter.recordRequest(for: identifier, endpoint: endpoint)\n                \n                // Perform the actual request\n                Task {\n                    do {\n                        let result = try await request()\n                        continuation.resume(returning: result)\n                    } catch {\n                        continuation.resume(throwing: error)\n                    }\n                }\n            }\n        }\n    }\n}\n"