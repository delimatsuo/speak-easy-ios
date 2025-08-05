import Foundation
import XCTest

// MARK: - Test Configuration
struct TestConfiguration {
    static let mockAPIBaseURL = "https://mock-api.test"
    static let testAPIKey = "test_api_key_12345"
    static let testTimeout: TimeInterval = 10.0
    static let maxRetryAttempts = 3
    static let maxCacheSize = 10 * 1024 * 1024  // 10MB for testing
    static let testSilenceThreshold: TimeInterval = 0.5  // Shorter for testing
    
    // Test audio configuration
    static let testSampleRate = 16000
    static let testChannels = 1
    static let testBitDepth = 16
    
    // Performance test thresholds
    static let maxTranslationLatency: TimeInterval = 2.0
    static let maxSTTLatency: TimeInterval = 1.0
    static let maxTTSLatency: TimeInterval = 3.0
    static let maxMemoryUsage = 100 * 1024 * 1024  // 100MB
}

// MARK: - Base Test Case
class BaseTestCase: XCTestCase {
    
    override func setUp() {
        super.setUp()
        configureTestEnvironment()
        resetMockServices()
        clearTestCache()
    }
    
    override func tearDown() {
        clearTestData()
        resetNetworkMocks()
        super.tearDown()
    }
    
    private func configureTestEnvironment() {
        // Set test-specific user defaults
        UserDefaults.standard.set(TestConfiguration.testSilenceThreshold, forKey: "silence_threshold")
        UserDefaults.standard.set(false, forKey: "share_analytics")
        UserDefaults.standard.set(false, forKey: "store_translations")
        
        // Configure test audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            XCTFail("Failed to configure test audio session: \(error)")
        }
    }
    
    private func resetMockServices() {
        MockGeminiAPI.shared.reset()
        MockNetworkService.shared.reset()
        MockSpeechRecognizer.shared.reset()
    }
    
    private func clearTestCache() {
        // Clear any test cache data
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let testCacheURL = cacheDirectory.appendingPathComponent("test_cache")
        try? FileManager.default.removeItem(at: testCacheURL)
    }
    
    private func clearTestData() {
        // Clear test-specific data
        UserDefaults.standard.removeObject(forKey: "test_api_key")
        UserDefaults.standard.removeObject(forKey: "test_translations")
    }
    
    private func resetNetworkMocks() {
        MockURLProtocol.reset()
    }
}

// MARK: - Performance Test Case
class PerformanceTestCase: XCTestCase {
    
    func measureAsyncPerformance(
        of operation: @escaping () async throws -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        measure {
            let expectation = expectation(description: "Performance test")
            Task {
                do {
                    try await operation()
                } catch {
                    XCTFail("Performance test failed: \(error)", file: file, line: line)
                }
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: TestConfiguration.testTimeout)
        }
    }
    
    func measureMemoryUsage(during operation: @escaping () throws -> Void) -> Int64 {
        let startMemory = getMemoryUsage()
        try? operation()
        let endMemory = getMemoryUsage()
        return endMemory - startMemory
    }
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Test Helpers
extension XCTestCase {
    
    func waitForAsyncOperation<T>(
        _ operation: @escaping () async throws -> T,
        timeout: TimeInterval = TestConfiguration.testTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw XCTestError(.timeoutWhileWaiting)
            }
            
            guard let result = try await group.next() else {
                throw XCTestError(.failureWhileWaiting)
            }
            
            group.cancelAll()
            return result
        }
    }
    
    func expectAsync<T>(
        _ operation: @escaping () async throws -> T,
        timeout: TimeInterval = TestConfiguration.testTimeout,
        description: String = "Async operation",
        file: StaticString = #file,
        line: UInt = #line
    ) -> T? {
        var result: T?
        let expectation = expectation(description: description)
        
        Task {
            do {
                result = try await operation()
            } catch {
                XCTFail("Async operation failed: \(error)", file: file, line: line)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
        return result
    }
}

// MARK: - Audio Test Helpers
extension XCTestCase {
    
    func createTestAudioBuffer(
        duration: TimeInterval = 1.0,
        frequency: Float = 440.0,
        sampleRate: Double = 44100.0
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        // Generate test tone
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        let channelData = floatChannelData[0]
        
        for frame in 0..<Int(frameCount) {
            let sampleValue = sin(2.0 * Float.pi * frequency * Float(frame) / Float(sampleRate))
            channelData[frame] = sampleValue * 0.5 // 50% volume
        }
        
        return buffer
    }
    
    func createSilentAudioBuffer(
        duration: TimeInterval = 1.0,
        sampleRate: Double = 44100.0
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        // Fill with silence (zeros)
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        let channelData = floatChannelData[0]
        
        for frame in 0..<Int(frameCount) {
            channelData[frame] = 0.0
        }
        
        return buffer
    }
}

// MARK: - Network Test Helpers
extension XCTestCase {
    
    func simulateNetworkDelay(_ delay: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
    
    func simulateNetworkError() -> URLError {
        return URLError(.networkConnectionLost)
    }
    
    func simulateTimeoutError() -> URLError {
        return URLError(.timedOut)
    }
}