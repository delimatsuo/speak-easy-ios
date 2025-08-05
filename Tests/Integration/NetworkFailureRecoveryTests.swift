import XCTest
import Network
import Foundation
@testable import UniversalTranslatorApp

// MARK: - Network Failure Recovery and Offline Testing
class NetworkFailureRecoveryTests: BaseTestCase {
    
    var networkMonitor: NetworkReachabilityMonitor!
    var offlineManager: OfflineTranslationManager!
    var retryManager: RetryManager!
    var cacheManager: TranslationCacheManager!
    
    override func setUp() {
        super.setUp()
        setupNetworkComponents()
    }
    
    override func tearDown() {
        teardownNetworkComponents()
        super.tearDown()
    }
    
    private func setupNetworkComponents() {
        networkMonitor = NetworkReachabilityMonitor()
        offlineManager = OfflineTranslationManager()
        retryManager = RetryManager()
        cacheManager = TranslationCacheManager()
    }
    
    private func teardownNetworkComponents() {
        networkMonitor?.stopMonitoring()
        offlineManager = nil
        retryManager = nil
        cacheManager = nil
    }
    
    // MARK: - Network State Detection Tests
    
    func testNetworkStateDetection() {
        let expectation = expectation(description: "Network state detection")
        
        Task {
            // Start monitoring network
            await networkMonitor.startMonitoring()
            
            // Wait for initial network state
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            
            let initialState = await networkMonitor.getCurrentNetworkState()
            XCTAssertNotNil(initialState)
            
            // Test state change notifications
            var stateChanges: [NetworkState] = []
            
            await networkMonitor.onNetworkStateChange { newState in
                stateChanges.append(newState)
            }
            
            // Simulate network changes
            await networkMonitor.simulateNetworkChange(.wifi)
            await networkMonitor.simulateNetworkChange(.cellular)
            await networkMonitor.simulateNetworkChange(.none)
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            XCTAssertGreaterThan(stateChanges.count, 0)
            XCTAssertTrue(stateChanges.contains(.none), "Should detect network disconnection")
            
            print("✅ Network state detection working correctly")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testNetworkQualityAssessment() {
        let expectation = expectation(description: "Network quality assessment")
        
        Task {
            // Test different network conditions
            let networkConditions: [NetworkCondition] = [
                .excellent(latency: 20, bandwidth: 100_000_000), // 20ms, 100Mbps
                .good(latency: 50, bandwidth: 10_000_000),       // 50ms, 10Mbps
                .poor(latency: 200, bandwidth: 1_000_000),       // 200ms, 1Mbps
                .veryPoor(latency: 1000, bandwidth: 100_000)     // 1s, 100Kbps
            ]
            
            for condition in networkConditions {
                await networkMonitor.simulateNetworkCondition(condition)
                
                let quality = await networkMonitor.assessNetworkQuality()
                
                switch condition {
                case .excellent:
                    XCTAssertEqual(quality.level, .excellent)
                    XCTAssertTrue(quality.canHandleRealTimeTranslation)
                case .good:
                    XCTAssertEqual(quality.level, .good)
                    XCTAssertTrue(quality.canHandleRealTimeTranslation)
                case .poor:
                    XCTAssertEqual(quality.level, .poor)
                    XCTAssertFalse(quality.canHandleRealTimeTranslation)
                case .veryPoor:
                    XCTAssertEqual(quality.level, .veryPoor)
                    XCTAssertFalse(quality.canHandleRealTimeTranslation)
                }
                
                print("✅ Network quality assessment: \(quality.level)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Offline Translation Tests
    
    func testOfflineTranslationFallback() {
        let expectation = expectation(description: "Offline translation fallback")
        
        Task {
            // Pre-populate cache with common translations
            let commonTranslations = [
                ("Hello", "en", "es", "Hola"),
                ("Thank you", "en", "es", "Gracias"),
                ("Good morning", "en", "es", "Buenos días"),
                ("How are you?", "en", "es", "¿Cómo estás?"),
                ("Goodbye", "en", "es", "Adiós")
            ]
            
            for (source, sourceLang, targetLang, translation) in commonTranslations {
                await cacheManager.storeTranslation(
                    source: source,
                    translation: translation,
                    sourceLang: sourceLang,
                    targetLang: targetLang,
                    metadata: CacheMetadata(
                        timestamp: Date(),
                        confidence: 0.95,
                        source: .apiCache
                    )
                )
            }
            
            // Simulate network disconnection
            await networkMonitor.simulateNetworkChange(.none)
            
            // Test offline translation
            for (source, sourceLang, targetLang, expectedTranslation) in commonTranslations {
                do {
                    let result = try await offlineManager.translateText(
                        source,
                        from: sourceLang,
                        to: targetLang
                    )
                    
                    XCTAssertEqual(result.translation, expectedTranslation)
                    XCTAssertEqual(result.source, .cache)
                    XCTAssertTrue(result.isOffline)
                    
                } catch {
                    XCTFail("Offline translation failed for '\(source)': \(error)")
                }
            }
            
            // Test unknown translation (should fail gracefully)
            do {
                _ = try await offlineManager.translateText(
                    "This phrase is not cached",
                    from: "en",
                    to: "es"
                )
                XCTFail("Should fail for uncached translation")
            } catch OfflineTranslationError.translationNotAvailable {
                XCTAssertTrue(true, "Correctly handled unavailable offline translation")
            }
            
            print("✅ Offline translation fallback working correctly")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
    
    func testOfflineModeFeatureAdaptation() {
        let expectation = expectation(description: "Offline mode feature adaptation")
        
        Task {
            // Test online mode features
            await networkMonitor.simulateNetworkChange(.wifi)
            let onlineFeatures = await offlineManager.getAvailableFeatures()
            
            XCTAssertTrue(onlineFeatures.realTimeTranslation)
            XCTAssertTrue(onlineFeatures.textToSpeech)
            XCTAssertTrue(onlineFeatures.languageDetection)
            XCTAssertTrue(onlineFeatures.cacheUpdates)
            
            // Test offline mode features
            await networkMonitor.simulateNetworkChange(.none)
            let offlineFeatures = await offlineManager.getAvailableFeatures()
            
            XCTAssertFalse(offlineFeatures.realTimeTranslation)
            XCTAssertFalse(offlineFeatures.textToSpeech)
            XCTAssertFalse(offlineFeatures.languageDetection)
            XCTAssertFalse(offlineFeatures.cacheUpdates)
            XCTAssertTrue(offlineFeatures.cachedTranslations)
            XCTAssertTrue(offlineFeatures.offlineHistory)
            
            // Test partial connectivity features
            await networkMonitor.simulateNetworkCondition(.poor(latency: 500, bandwidth: 50_000))
            let limitedFeatures = await offlineManager.getAvailableFeatures()
            
            XCTAssertFalse(limitedFeatures.realTimeTranslation)
            XCTAssertTrue(limitedFeatures.textToSpeech) // May work with delay
            XCTAssertTrue(limitedFeatures.languageDetection)
            
            print("✅ Offline mode feature adaptation working correctly")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Request Retry and Recovery Tests
    
    func testExponentialBackoffRetry() {
        let expectation = expectation(description: "Exponential backoff retry")
        
        Task {
            let failureCount = 3
            var attemptCount = 0
            var retryDelays: [TimeInterval] = []
            
            do {
                _ = try await retryManager.executeWithRetry(
                    maxRetries: 4,
                    baseDelay: 0.1 // 100ms for testing
                ) {
                    attemptCount += 1
                    let startTime = Date()
                    
                    defer {
                        if attemptCount > 1 {
                            let delay = Date().timeIntervalSince(startTime)
                            retryDelays.append(delay)
                        }
                    }
                    
                    if attemptCount <= failureCount {
                        throw NetworkError.temporaryFailure
                    }
                    
                    return "Success after \(attemptCount) attempts"
                }
                
                // Verify retry pattern
                XCTAssertEqual(attemptCount, failureCount + 1)
                XCTAssertEqual(retryDelays.count, failureCount)
                
                // Verify exponential growth (allowing for timing variance)
                for i in 1..<retryDelays.count {
                    let expectedRatio = 2.0
                    let actualRatio = retryDelays[i] / retryDelays[i-1]
                    XCTAssertGreaterThan(actualRatio, expectedRatio * 0.8, "Delay should increase exponentially")
                }
                
                print("✅ Exponential backoff retry working correctly")
                
            } catch {
                XCTFail("Retry should have succeeded: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCircuitBreakerPattern() {
        let expectation = expectation(description: "Circuit breaker pattern")
        
        Task {
            let circuitBreaker = CircuitBreaker(
                failureThreshold: 3,
                recoveryTimeout: 2.0,
                monitoringPeriod: 1.0
            )
            
            var callCount = 0
            
            // Test failure accumulation
            for i in 0..<5 {
                do {
                    _ = try await circuitBreaker.call {
                        callCount += 1
                        throw NetworkError.serviceUnavailable
                    }
                    XCTFail("Call \(i) should have failed")
                } catch CircuitBreakerError.circuitOpen {
                    // Circuit should open after threshold
                    XCTAssertGreaterThanOrEqual(i, 3, "Circuit should open after failure threshold")
                    print("✅ Circuit opened after \(i) failures")
                } catch NetworkError.serviceUnavailable {
                    // Expected for first few attempts
                    XCTAssertLessThan(i, 3, "Service error expected before circuit opens")
                }
            }
            
            // Verify circuit is open
            let initialState = await circuitBreaker.getState()
            XCTAssertEqual(initialState, .open)
            
            // Wait for recovery timeout
            try? await Task.sleep(nanoseconds: UInt64(2.5 * 1_000_000_000)) // 2.5 seconds
            
            // Test recovery
            do {
                let result = try await circuitBreaker.call {
                    return "Recovery successful"
                }
                
                XCTAssertEqual(result, "Recovery successful")
                
                let finalState = await circuitBreaker.getState()
                XCTAssertEqual(finalState, .closed)
                
                print("✅ Circuit breaker recovery working correctly")
                
            } catch {
                XCTFail("Circuit breaker recovery failed: \(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testRequestQueuing() {
        let expectation = expectation(description: "Request queuing")
        
        Task {
            let requestQueue = NetworkRequestQueue(maxSize: 50)
            
            // Simulate network disconnection
            await networkMonitor.simulateNetworkChange(.none)
            
            // Queue multiple requests while offline
            let testRequests = [
                TranslationRequest(text: "Hello", from: "en", to: "es"),
                TranslationRequest(text: "Goodbye", from: "en", to: "es"),
                TranslationRequest(text: "Thank you", from: "en", to: "fr"),
                TranslationRequest(text: "Good morning", from: "en", to: "de")
            ]
            
            for request in testRequests {
                let queued = await requestQueue.enqueue(request)
                XCTAssertTrue(queued, "Request should be queued while offline")
            }
            
            let queueSize = await requestQueue.getQueueSize()
            XCTAssertEqual(queueSize, testRequests.count)
            
            // Simulate network restoration
            await networkMonitor.simulateNetworkChange(.wifi)
            
            // Process queued requests
            var processedCount = 0
            
            await requestQueue.processQueuedRequests { request in
                processedCount += 1
                return TranslationResult(
                    translation: "Translated: \(request.text)",
                    confidence: 0.9,
                    fromCache: false
                )
            }
            
            XCTAssertEqual(processedCount, testRequests.count)
            
            let finalQueueSize = await requestQueue.getQueueSize()
            XCTAssertEqual(finalQueueSize, 0)
            
            print("✅ Request queuing working correctly")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 8.0)
    }
    
    // MARK: - Progressive Degradation Tests
    
    func testProgressiveDegradation() {
        let expectation = expectation(description: "Progressive degradation")
        
        Task {
            let degradationManager = ProgressiveDegradationManager()
            
            // Test excellent network conditions
            await networkMonitor.simulateNetworkCondition(.excellent(latency: 20, bandwidth: 100_000_000))
            let excellentConfig = await degradationManager.getOptimalConfiguration()
            
            XCTAssertEqual(excellentConfig.translationQuality, .high)
            XCTAssertEqual(excellentConfig.audioQuality, .high)
            XCTAssertTrue(excellentConfig.enableRealTimeFeatures)
            XCTAssertEqual(excellentConfig.cacheStrategy, .minimal)
            
            // Test good network conditions
            await networkMonitor.simulateNetworkCondition(.good(latency: 100, bandwidth: 5_000_000))
            let goodConfig = await degradationManager.getOptimalConfiguration()
            
            XCTAssertEqual(goodConfig.translationQuality, .medium)
            XCTAssertEqual(goodConfig.audioQuality, .medium)
            XCTAssertTrue(goodConfig.enableRealTimeFeatures)
            XCTAssertEqual(goodConfig.cacheStrategy, .moderate)
            
            // Test poor network conditions
            await networkMonitor.simulateNetworkCondition(.poor(latency: 500, bandwidth: 500_000))
            let poorConfig = await degradationManager.getOptimalConfiguration()
            
            XCTAssertEqual(poorConfig.translationQuality, .low)
            XCTAssertEqual(poorConfig.audioQuality, .low)
            XCTAssertFalse(poorConfig.enableRealTimeFeatures)
            XCTAssertEqual(poorConfig.cacheStrategy, .aggressive)
            
            // Test offline conditions
            await networkMonitor.simulateNetworkChange(.none)
            let offlineConfig = await degradationManager.getOptimalConfiguration()
            
            XCTAssertEqual(offlineConfig.translationQuality, .cacheOnly)
            XCTAssertEqual(offlineConfig.audioQuality, .disabled)
            XCTAssertFalse(offlineConfig.enableRealTimeFeatures)
            XCTAssertEqual(offlineConfig.cacheStrategy, .cacheOnly)
            
            print("✅ Progressive degradation working correctly")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 6.0)
    }
    
    func testAdaptiveTimeouts() {
        let expectation = expectation(description: "Adaptive timeouts")
        
        Task {
            let timeoutManager = AdaptiveTimeoutManager()
            
            // Test timeout adaptation based on network conditions
            let networkConditions: [(NetworkCondition, TimeInterval)] = [
                (.excellent(latency: 20, bandwidth: 100_000_000), 2.0),
                (.good(latency: 100, bandwidth: 5_000_000), 5.0),
                (.poor(latency: 500, bandwidth: 500_000), 15.0),
                (.veryPoor(latency: 2000, bandwidth: 100_000), 30.0)
            ]
            
            for (condition, expectedMinTimeout) in networkConditions {
                await networkMonitor.simulateNetworkCondition(condition)
                
                let timeout = await timeoutManager.getAdaptiveTimeout(for: .translation)
                
                XCTAssertGreaterThanOrEqual(timeout, expectedMinTimeout)
                
                print("✅ Adaptive timeout for \(condition): \(timeout)s")
            }
            
            // Test timeout learning from actual response times
            await timeoutManager.recordResponseTime(5.0, for: .translation)
            await timeoutManager.recordResponseTime(7.0, for: .translation)
            await timeoutManager.recordResponseTime(6.0, for: .translation)
            
            let learnedTimeout = await timeoutManager.getAdaptiveTimeout(for: .translation)
            XCTAssertGreaterThan(learnedTimeout, 6.0, "Timeout should adapt to observed response times")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}

// MARK: - Supporting Implementations
class NetworkReachabilityMonitor {
    private var currentState: NetworkState = .wifi
    private var stateChangeCallback: ((NetworkState) -> Void)?
    private var currentCondition: NetworkCondition = .excellent(latency: 20, bandwidth: 100_000_000)
    
    func startMonitoring() async {
        // Start network monitoring
    }
    
    func stopMonitoring() {
        // Stop monitoring
    }
    
    func getCurrentNetworkState() async -> NetworkState {
        return currentState
    }
    
    func onNetworkStateChange(_ callback: @escaping (NetworkState) -> Void) async {
        stateChangeCallback = callback
    }
    
    func simulateNetworkChange(_ newState: NetworkState) async {
        currentState = newState
        stateChangeCallback?(newState)
    }
    
    func simulateNetworkCondition(_ condition: NetworkCondition) async {
        currentCondition = condition
    }
    
    func assessNetworkQuality() async -> NetworkQuality {
        switch currentCondition {
        case .excellent:
            return NetworkQuality(level: .excellent, canHandleRealTimeTranslation: true)
        case .good:
            return NetworkQuality(level: .good, canHandleRealTimeTranslation: true)
        case .poor:
            return NetworkQuality(level: .poor, canHandleRealTimeTranslation: false)
        case .veryPoor:
            return NetworkQuality(level: .veryPoor, canHandleRealTimeTranslation: false)
        }
    }
}

enum NetworkState {
    case wifi
    case cellular
    case none
}

enum NetworkCondition {
    case excellent(latency: Int, bandwidth: Int)
    case good(latency: Int, bandwidth: Int)
    case poor(latency: Int, bandwidth: Int)
    case veryPoor(latency: Int, bandwidth: Int)
}

struct NetworkQuality {
    let level: QualityLevel
    let canHandleRealTimeTranslation: Bool
    
    enum QualityLevel {
        case excellent, good, poor, veryPoor
    }
}

class OfflineTranslationManager {
    private let cacheManager = TranslationCacheManager()
    
    func translateText(_ text: String, from sourceLanguage: String, to targetLanguage: String) async throws -> OfflineTranslationResult {
        if let cachedTranslation = await cacheManager.getCachedTranslation(
            source: text,
            sourceLang: sourceLanguage,
            targetLang: targetLanguage
        ) {
            return OfflineTranslationResult(
                translation: cachedTranslation.translation,
                source: .cache,
                isOffline: true,
                confidence: cachedTranslation.confidence
            )
        }
        
        throw OfflineTranslationError.translationNotAvailable
    }
    
    func getAvailableFeatures() async -> OfflineFeatures {
        let networkState = await NetworkReachabilityMonitor().getCurrentNetworkState()
        
        switch networkState {
        case .wifi:
            return OfflineFeatures(
                realTimeTranslation: true,
                textToSpeech: true,
                languageDetection: true,
                cacheUpdates: true,
                cachedTranslations: true,
                offlineHistory: true
            )
        case .cellular:
            return OfflineFeatures(
                realTimeTranslation: true,
                textToSpeech: true,
                languageDetection: true,
                cacheUpdates: false, // Preserve data
                cachedTranslations: true,
                offlineHistory: true
            )
        case .none:
            return OfflineFeatures(
                realTimeTranslation: false,
                textToSpeech: false,
                languageDetection: false,
                cacheUpdates: false,
                cachedTranslations: true,
                offlineHistory: true
            )
        }
    }
}

struct OfflineTranslationResult {
    let translation: String
    let source: TranslationSource
    let isOffline: Bool
    let confidence: Float
}

enum TranslationSource {
    case api, cache
}

enum OfflineTranslationError: Error {
    case translationNotAvailable
    case cacheCorrupted
}

struct OfflineFeatures {
    let realTimeTranslation: Bool
    let textToSpeech: Bool
    let languageDetection: Bool
    let cacheUpdates: Bool
    let cachedTranslations: Bool
    let offlineHistory: Bool
}

class TranslationCacheManager {
    private var cache: [String: CachedTranslation] = [:]
    
    func storeTranslation(source: String, translation: String, sourceLang: String, targetLang: String, metadata: CacheMetadata) async {
        let key = "\(sourceLang)_\(targetLang)_\(source.hashValue)"
        cache[key] = CachedTranslation(
            source: source,
            translation: translation,
            sourceLang: sourceLang,
            targetLang: targetLang,
            confidence: metadata.confidence,
            timestamp: metadata.timestamp
        )
    }
    
    func getCachedTranslation(source: String, sourceLang: String, targetLang: String) async -> CachedTranslation? {
        let key = "\(sourceLang)_\(targetLang)_\(source.hashValue)"
        return cache[key]
    }
}

struct CachedTranslation {
    let source: String
    let translation: String
    let sourceLang: String
    let targetLang: String
    let confidence: Float
    let timestamp: Date
}

struct CacheMetadata {
    let timestamp: Date
    let confidence: Float
    let source: CacheSource
}

enum CacheSource {
    case apiCache, userInput, offlineDatabase
}

class RetryManager {
    func executeWithRetry<T>(
        maxRetries: Int,
        baseDelay: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxRetries {
                    let delay = baseDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.maxRetriesExceeded
    }
}

enum NetworkError: Error {
    case temporaryFailure
    case serviceUnavailable
    case maxRetriesExceeded
}

class CircuitBreaker {
    private let failureThreshold: Int
    private let recoveryTimeout: TimeInterval
    private let monitoringPeriod: TimeInterval
    
    private var state: CircuitState = .closed
    private var failureCount = 0
    private var lastFailureTime: Date?
    
    init(failureThreshold: Int, recoveryTimeout: TimeInterval, monitoringPeriod: TimeInterval) {
        self.failureThreshold = failureThreshold
        self.recoveryTimeout = recoveryTimeout
        self.monitoringPeriod = monitoringPeriod
    }
    
    func call<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        switch state {
        case .open:
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) > recoveryTimeout {
                state = .halfOpen
            } else {
                throw CircuitBreakerError.circuitOpen
            }
        case .closed, .halfOpen:
            break
        }
        
        do {
            let result = try await operation()
            onSuccess()
            return result
        } catch {
            onFailure()
            throw error
        }
    }
    
    func getState() async -> CircuitState {
        return state
    }
    
    private func onSuccess() {
        failureCount = 0
        state = .closed
    }
    
    private func onFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= failureThreshold {
            state = .open
        }
    }
}

enum CircuitState {
    case closed, open, halfOpen
}

enum CircuitBreakerError: Error {
    case circuitOpen
}

class NetworkRequestQueue {
    private let maxSize: Int
    private var queue: [TranslationRequest] = []
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func enqueue(_ request: TranslationRequest) async -> Bool {
        guard queue.count < maxSize else { return false }
        queue.append(request)
        return true
    }
    
    func getQueueSize() async -> Int {
        return queue.count
    }
    
    func processQueuedRequests(_ processor: @escaping (TranslationRequest) async -> TranslationResult) async {
        while !queue.isEmpty {
            let request = queue.removeFirst()
            _ = await processor(request)
        }
    }
}

struct TranslationRequest {
    let text: String
    let from: String
    let to: String
}

struct TranslationResult {
    let translation: String
    let confidence: Float
    let fromCache: Bool
}

class ProgressiveDegradationManager {
    func getOptimalConfiguration() async -> DegradationConfiguration {
        let networkMonitor = NetworkReachabilityMonitor()
        let networkState = await networkMonitor.getCurrentNetworkState()
        let quality = await networkMonitor.assessNetworkQuality()
        
        switch quality.level {
        case .excellent:
            return DegradationConfiguration(
                translationQuality: .high,
                audioQuality: .high,
                enableRealTimeFeatures: true,
                cacheStrategy: .minimal
            )
        case .good:
            return DegradationConfiguration(
                translationQuality: .medium,
                audioQuality: .medium,
                enableRealTimeFeatures: true,
                cacheStrategy: .moderate
            )
        case .poor:
            return DegradationConfiguration(
                translationQuality: .low,
                audioQuality: .low,
                enableRealTimeFeatures: false,
                cacheStrategy: .aggressive
            )
        case .veryPoor:
            return DegradationConfiguration(
                translationQuality: .cacheOnly,
                audioQuality: .disabled,
                enableRealTimeFeatures: false,
                cacheStrategy: .cacheOnly
            )
        }
    }
}

struct DegradationConfiguration {
    let translationQuality: QualityLevel
    let audioQuality: QualityLevel
    let enableRealTimeFeatures: Bool
    let cacheStrategy: CacheStrategy
    
    enum QualityLevel {
        case high, medium, low, cacheOnly, disabled
    }
    
    enum CacheStrategy {
        case minimal, moderate, aggressive, cacheOnly
    }
}

class AdaptiveTimeoutManager {
    private var responseTimes: [OperationType: [TimeInterval]] = [:]
    
    func getAdaptiveTimeout(for operation: OperationType) async -> TimeInterval {
        let baseTimeout: TimeInterval
        
        // Get base timeout based on network conditions
        let networkMonitor = NetworkReachabilityMonitor()
        let quality = await networkMonitor.assessNetworkQuality()
        
        switch quality.level {
        case .excellent:
            baseTimeout = 2.0
        case .good:
            baseTimeout = 5.0
        case .poor:
            baseTimeout = 15.0
        case .veryPoor:
            baseTimeout = 30.0
        }
        
        // Adjust based on historical response times
        if let times = responseTimes[operation], !times.isEmpty {
            let average = times.reduce(0, +) / Double(times.count)
            let maxTime = times.max() ?? 0
            
            // Use max of base timeout and (average + buffer)
            return max(baseTimeout, average * 1.5, maxTime * 1.2)
        }
        
        return baseTimeout
    }
    
    func recordResponseTime(_ time: TimeInterval, for operation: OperationType) async {
        if responseTimes[operation] == nil {
            responseTimes[operation] = []
        }
        
        responseTimes[operation]?.append(time)
        
        // Keep only recent times (last 10)
        if responseTimes[operation]!.count > 10 {
            responseTimes[operation]?.removeFirst()
        }
    }
}

enum OperationType {
    case translation, tts, languageDetection
}