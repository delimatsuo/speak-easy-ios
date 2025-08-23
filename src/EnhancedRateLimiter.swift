import Foundation
import Dispatch

/// Enterprise-grade rate limiting system with sliding window algorithm and distributed support
public class EnhancedRateLimiter {
    
    // MARK: - Types
    
    public struct RateLimit {
        public let requests: Int
        public let windowSize: TimeInterval
        public let identifier: String
        
        public init(requests: Int, windowSize: TimeInterval, identifier: String) {
            self.requests = requests
            self.windowSize = windowSize
            self.identifier = identifier
        }
    }
    
    public struct RateLimitResult {
        public let allowed: Bool
        public let remainingRequests: Int
        public let resetTime: Date
        public let retryAfter: TimeInterval?
        public let violationCount: Int
        
        public init(allowed: Bool, remainingRequests: Int, resetTime: Date, retryAfter: TimeInterval? = nil, violationCount: Int = 0) {
            self.allowed = allowed
            self.remainingRequests = remainingRequests
            self.resetTime = resetTime
            self.retryAfter = retryAfter
            self.violationCount = violationCount
        }
    }
    
    public enum RateLimitError: Error, LocalizedError {
        case rateLimitExceeded(RateLimitResult)
        case invalidConfiguration
        case distributedStoreError(String)
        
        public var errorDescription: String? {
            switch self {
            case .rateLimitExceeded(let result):
                return "Rate limit exceeded. Retry after: \(result.retryAfter ?? 0) seconds"
            case .invalidConfiguration:
                return "Invalid rate limit configuration"
            case .distributedStoreError(let message):
                return "Distributed store error: \(message)"
            }
        }
    }
    
    // MARK: - Window Entry
    
    private struct WindowEntry {
        let timestamp: Date
        let count: Int
        
        init(timestamp: Date = Date(), count: Int = 1) {
            self.timestamp = timestamp
            self.count = count
        }
    }
    
    // MARK: - Violation Tracking
    
    private struct ViolationRecord {
        let timestamp: Date
        let consecutiveViolations: Int
        let totalViolations: Int
        let backoffUntil: Date?
        
        init(timestamp: Date = Date(), consecutiveViolations: Int = 1, totalViolations: Int = 1, backoffUntil: Date? = nil) {
            self.timestamp = timestamp
            self.consecutiveViolations = consecutiveViolations
            self.totalViolations = totalViolations
            self.backoffUntil = backoffUntil
        }
    }
    
    // MARK: - Properties
    
    private let queue = DispatchQueue(label: "rate.limiter", attributes: .concurrent)
    private var slidingWindows: [String: [WindowEntry]] = [:]
    private var violationRecords: [String: ViolationRecord] = [:]
    private var rateLimits: [String: RateLimit] = [:]
    
    // Configuration
    private let cleanupInterval: TimeInterval = 300 // 5 minutes
    private let maxViolationHistory = 1000
    private var lastCleanup = Date()
    
    // Exponential backoff configuration
    private let baseBackoffSeconds: TimeInterval = 1
    private let maxBackoffSeconds: TimeInterval = 3600 // 1 hour
    private let backoffMultiplier: Double = 2.0
    
    // Distributed store support
    public weak var distributedStore: RateLimitDistributedStore?
    
    public init() {}
    
    // MARK: - Rate Limit Configuration
    
    /// Registers a rate limit for a specific identifier
    public func setRateLimit(_ rateLimit: RateLimit) {
        queue.async(flags: .barrier) {
            self.rateLimits[rateLimit.identifier] = rateLimit
        }
    }
    
    /// Removes rate limit for identifier
    public func removeRateLimit(for identifier: String) {
        queue.async(flags: .barrier) {
            self.rateLimits.removeValue(forKey: identifier)
            self.slidingWindows.removeValue(forKey: identifier)
            self.violationRecords.removeValue(forKey: identifier)
        }
    }
    
    // MARK: - Rate Limiting Core
    
    /// Checks if request is within rate limit using sliding window algorithm
    public func checkRateLimit(for identifier: String, userID: String? = nil) -> RateLimitResult {
        return queue.sync {
            let key = buildKey(identifier: identifier, userID: userID)
            
            guard let rateLimit = rateLimits[identifier] else {
                return RateLimitResult(allowed: true, remainingRequests: Int.max, resetTime: Date.distantFuture)
            }
            
            let now = Date()
            
            // Check for active exponential backoff
            if let violationRecord = violationRecords[key],
               let backoffUntil = violationRecord.backoffUntil,
               now < backoffUntil {
                let retryAfter = backoffUntil.timeIntervalSince(now)
                return RateLimitResult(
                    allowed: false,
                    remainingRequests: 0,
                    resetTime: backoffUntil,
                    retryAfter: retryAfter,
                    violationCount: violationRecord.totalViolations
                )
            }
            
            // Get current window
            var window = slidingWindows[key] ?? []
            
            // Remove expired entries
            let windowStart = now.addingTimeInterval(-rateLimit.windowSize)
            window = window.filter { $0.timestamp >= windowStart }
            
            // Count current requests
            let currentRequests = window.reduce(0) { $0 + $1.count }
            let remainingRequests = max(0, rateLimit.requests - currentRequests - 1)
            
            if currentRequests >= rateLimit.requests {
                // Rate limit exceeded - record violation
                let violation = recordViolation(for: key, now: now)
                let backoffTime = calculateExponentialBackoff(violations: violation.consecutiveViolations)
                let backoffUntil = now.addingTimeInterval(backoffTime)
                
                // Update violation record with backoff
                violationRecords[key] = ViolationRecord(
                    timestamp: now,
                    consecutiveViolations: violation.consecutiveViolations,
                    totalViolations: violation.totalViolations,
                    backoffUntil: backoffUntil
                )
                
                return RateLimitResult(
                    allowed: false,
                    remainingRequests: 0,
                    resetTime: windowStart.addingTimeInterval(rateLimit.windowSize),
                    retryAfter: backoffTime,
                    violationCount: violation.totalViolations
                )
            } else {
                // Request allowed - add to window
                window.append(WindowEntry(timestamp: now))
                slidingWindows[key] = window
                
                // Reset consecutive violations on successful request
                if let violation = violationRecords[key] {
                    violationRecords[key] = ViolationRecord(
                        timestamp: now,
                        consecutiveViolations: 0,
                        totalViolations: violation.totalViolations,
                        backoffUntil: nil
                    )
                }
                
                let nextReset = windowStart.addingTimeInterval(rateLimit.windowSize)
                return RateLimitResult(
                    allowed: true,
                    remainingRequests: remainingRequests,
                    resetTime: nextReset
                )
            }
        }
    }
    
    /// Increments request count (for successful requests)
    public func incrementCount(for identifier: String, userID: String? = nil, count: Int = 1) {
        queue.async(flags: .barrier) {
            let key = self.buildKey(identifier: identifier, userID: userID)
            var window = self.slidingWindows[key] ?? []
            window.append(WindowEntry(timestamp: Date(), count: count))
            self.slidingWindows[key] = window
            
            // Cleanup if needed
            self.cleanupIfNeeded()
        }
    }
    
    // MARK: - Exponential Backoff
    
    private func recordViolation(for key: String, now: Date) -> ViolationRecord {
        let existing = violationRecords[key]
        let consecutiveViolations = (existing?.consecutiveViolations ?? 0) + 1
        let totalViolations = (existing?.totalViolations ?? 0) + 1
        
        let violation = ViolationRecord(
            timestamp: now,
            consecutiveViolations: consecutiveViolations,
            totalViolations: totalViolations
        )
        
        violationRecords[key] = violation
        return violation
    }
    
    private func calculateExponentialBackoff(violations: Int) -> TimeInterval {
        let backoff = baseBackoffSeconds * pow(backoffMultiplier, Double(violations - 1))
        return min(backoff, maxBackoffSeconds)
    }
    
    // MARK: - Multi-tier Rate Limiting
    
    /// Applies multiple rate limits in hierarchy (per-user, per-endpoint, global)
    public func checkMultipleLimits(userID: String, endpoint: String, global: Bool = true) -> RateLimitResult {
        // Check user-specific limit first
        let userResult = checkRateLimit(for: "user", userID: userID)
        if !userResult.allowed {
            return userResult
        }
        
        // Check endpoint-specific limit
        let endpointResult = checkRateLimit(for: endpoint, userID: userID)
        if !endpointResult.allowed {
            return endpointResult
        }
        
        // Check global limit if enabled
        if global {
            let globalResult = checkRateLimit(for: "global")
            if !globalResult.allowed {
                return globalResult
            }
        }
        
        // Return the most restrictive result
        let minRemaining = min(userResult.remainingRequests, endpointResult.remainingRequests)
        let earliestReset = min(userResult.resetTime, endpointResult.resetTime)
        
        return RateLimitResult(
            allowed: true,
            remainingRequests: minRemaining,
            resetTime: earliestReset
        )
    }
    
    // MARK: - Burst Handling
    
    /// Handles burst requests with token bucket algorithm
    public func checkBurstLimit(for identifier: String, burstSize: Int, refillRate: Double) -> RateLimitResult {
        return queue.sync {
            let key = "burst_\(identifier)"
            let now = Date()
            
            // Get or create bucket state
            var bucket = burstBuckets[key] ?? BurstBucket(
                tokens: Double(burstSize),
                lastRefill: now,
                capacity: Double(burstSize)
            )
            
            // Refill tokens based on time elapsed
            let timeElapsed = now.timeIntervalSince(bucket.lastRefill)
            let tokensToAdd = timeElapsed * refillRate
            bucket.tokens = min(bucket.capacity, bucket.tokens + tokensToAdd)
            bucket.lastRefill = now
            
            if bucket.tokens >= 1.0 {
                // Request allowed
                bucket.tokens -= 1.0
                burstBuckets[key] = bucket
                
                return RateLimitResult(
                    allowed: true,
                    remainingRequests: Int(bucket.tokens),
                    resetTime: now.addingTimeInterval(1.0 / refillRate)
                )
            } else {
                // Request denied
                let retryAfter = (1.0 - bucket.tokens) / refillRate
                return RateLimitResult(
                    allowed: false,
                    remainingRequests: 0,
                    resetTime: now.addingTimeInterval(retryAfter),
                    retryAfter: retryAfter
                )
            }
        }
    }
    
    // MARK: - Burst Bucket Support
    
    private struct BurstBucket {
        var tokens: Double
        var lastRefill: Date
        let capacity: Double
    }
    
    private var burstBuckets: [String: BurstBucket] = [:]
    
    // MARK: - Utility Methods
    
    private func buildKey(identifier: String, userID: String?) -> String {
        if let userID = userID {
            return "\(identifier):\(userID)"
        }
        return identifier
    }
    
    private func cleanupIfNeeded() {
        let now = Date()
        if now.timeIntervalSince(lastCleanup) > cleanupInterval {
            cleanup()
            lastCleanup = now
        }
    }
    
    private func cleanup() {
        let now = Date()
        
        // Clean up expired windows
        for (key, limit) in rateLimits {
            if var window = slidingWindows[key] {
                let windowStart = now.addingTimeInterval(-limit.windowSize)
                window = window.filter { $0.timestamp >= windowStart }
                
                if window.isEmpty {
                    slidingWindows.removeValue(forKey: key)
                } else {
                    slidingWindows[key] = window
                }
            }
        }
        
        // Clean up old violation records
        violationRecords = violationRecords.compactMapValues { violation in
            let age = now.timeIntervalSince(violation.timestamp)
            return age < 3600 ? violation : nil // Keep records for 1 hour
        }
        
        // Clean up burst buckets
        burstBuckets = burstBuckets.compactMapValues { bucket in
            let age = now.timeIntervalSince(bucket.lastRefill)
            return age < 3600 ? bucket : nil // Keep buckets for 1 hour
        }
    }
    
    // MARK: - Statistics
    
    /// Gets current statistics for monitoring
    public func getStatistics() -> RateLimitStatistics {
        return queue.sync {
            let now = Date()
            var stats = RateLimitStatistics()
            
            for (key, window) in slidingWindows {
                let recentRequests = window.filter { 
                    now.timeIntervalSince($0.timestamp) < 60 // Last minute
                }.count
                
                stats.activeWindows += 1
                stats.totalRequests += window.count
                stats.recentRequests += recentRequests
            }
            
            stats.totalViolations = violationRecords.values.reduce(0) { $0 + $1.totalViolations }
            stats.activeViolations = violationRecords.values.filter { violation in
                if let backoffUntil = violation.backoffUntil {
                    return now < backoffUntil
                }
                return false
            }.count
            
            return stats
        }
    }
    
    /// Resets all rate limiting data for an identifier
    public func reset(for identifier: String, userID: String? = nil) {
        let key = buildKey(identifier: identifier, userID: userID)
        queue.async(flags: .barrier) {
            self.slidingWindows.removeValue(forKey: key)
            self.violationRecords.removeValue(forKey: key)
            self.burstBuckets.removeValue(forKey: "burst_\(key)")
        }
    }
    
    /// Resets all rate limiting data
    public func resetAll() {
        queue.async(flags: .barrier) {
            self.slidingWindows.removeAll()
            self.violationRecords.removeAll()
            self.burstBuckets.removeAll()
        }
    }
}

// MARK: - Statistics

public struct RateLimitStatistics {
    public var activeWindows: Int = 0
    public var totalRequests: Int = 0
    public var recentRequests: Int = 0
    public var totalViolations: Int = 0
    public var activeViolations: Int = 0
    
    public init() {}
}

// MARK: - Distributed Store Protocol

/// Protocol for distributed rate limiting storage (Redis, etc.)
public protocol RateLimitDistributedStore: AnyObject {
    func get(key: String) async throws -> Data?
    func set(key: String, value: Data, ttl: TimeInterval) async throws
    func increment(key: String, ttl: TimeInterval) async throws -> Int
    func delete(key: String) async throws
}

// MARK: - Distributed Rate Limiter

/// Distributed rate limiter using external store
public class DistributedRateLimiter: EnhancedRateLimiter {
    
    private let store: RateLimitDistributedStore
    private let keyPrefix: String
    
    public init(store: RateLimitDistributedStore, keyPrefix: String = "rate_limit:") {
        self.store = store
        self.keyPrefix = keyPrefix
        super.init()
    }
    
    /// Checks rate limit using distributed store
    public func checkDistributedRateLimit(for identifier: String, userID: String? = nil) async throws -> RateLimitResult {
        let key = keyPrefix + buildKey(identifier: identifier, userID: userID)
        
        guard let rateLimit = rateLimits[identifier] else {
            return RateLimitResult(allowed: true, remainingRequests: Int.max, resetTime: Date.distantFuture)
        }
        
        do {
            let count = try await store.increment(key: key, ttl: rateLimit.windowSize)
            let remainingRequests = max(0, rateLimit.requests - count)
            
            if count > rateLimit.requests {
                // Rate limit exceeded
                let retryAfter = rateLimit.windowSize
                return RateLimitResult(
                    allowed: false,
                    remainingRequests: 0,
                    resetTime: Date().addingTimeInterval(retryAfter),
                    retryAfter: retryAfter
                )
            } else {
                return RateLimitResult(
                    allowed: true,
                    remainingRequests: remainingRequests,
                    resetTime: Date().addingTimeInterval(rateLimit.windowSize)
                )
            }
        } catch {
            throw RateLimitError.distributedStoreError(error.localizedDescription)
        }
    }
}

// MARK: - Rate Limit Middleware

/// Middleware for automatic rate limiting in request processing
public struct RateLimitMiddleware {
    private let rateLimiter: EnhancedRateLimiter
    
    public init(rateLimiter: EnhancedRateLimiter) {
        self.rateLimiter = rateLimiter
    }
    
    /// Creates middleware function for request processing
    public func middleware(identifier: String) -> (String?) throws -> Void {
        return { userID in
            let result = self.rateLimiter.checkRateLimit(for: identifier, userID: userID)
            if !result.allowed {
                throw EnhancedRateLimiter.RateLimitError.rateLimitExceeded(result)
            }
        }
    }
    
    /// Creates async middleware for distributed rate limiting
    public func distributedMiddleware(identifier: String) -> (String?) async throws -> Void {
        guard let distributedLimiter = rateLimiter as? DistributedRateLimiter else {
            return middleware(identifier: identifier)
        }
        
        return { userID in
            let result = try await distributedLimiter.checkDistributedRateLimit(for: identifier, userID: userID)
            if !result.allowed {
                throw EnhancedRateLimiter.RateLimitError.rateLimitExceeded(result)
            }
        }
    }
}

// MARK: - Presets

public extension EnhancedRateLimiter {
    
    /// Common rate limit presets
    enum Preset {
        case strict      // 10 requests per minute
        case moderate    // 60 requests per minute
        case lenient     // 300 requests per minute
        case api         // 1000 requests per hour
        case burst       // 100 requests per 10 seconds
        
        var rateLimit: (requests: Int, windowSize: TimeInterval) {
            switch self {
            case .strict:
                return (10, 60)
            case .moderate:
                return (60, 60)
            case .lenient:
                return (300, 60)
            case .api:
                return (1000, 3600)
            case .burst:
                return (100, 10)
            }
        }
    }
    
    /// Applies a preset rate limit
    func applyPreset(_ preset: Preset, for identifier: String) {
        let (requests, windowSize) = preset.rateLimit
        let rateLimit = RateLimit(requests: requests, windowSize: windowSize, identifier: identifier)
        setRateLimit(rateLimit)
    }
}