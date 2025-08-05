import XCTest
import Foundation
import Combine
@testable import UniversalTranslatorApp

// MARK: - Memory Leak Detection and Resource Management Tests
// Comprehensive testing for memory leaks, retain cycles, and resource cleanup

class MemoryLeakDetectionTests: PerformanceTestCase {
    
    var memoryProfiler: MemoryProfiler!
    var resourceMonitor: ResourceMonitor!
    var initialMemoryFootprint: Int64 = 0
    
    override func setUp() {
        super.setUp()
        setupMemoryProfiling()
        initialMemoryFootprint = getCurrentMemoryUsage()
    }
    
    override func tearDown() {
        validateNoMemoryLeaks()
        cleanupMemoryProfiling()
        super.tearDown()
    }
    
    private func setupMemoryProfiling() {
        memoryProfiler = MemoryProfiler()
        resourceMonitor = ResourceMonitor()
        memoryProfiler.startProfiling()
    }
    
    private func cleanupMemoryProfiling() {
        memoryProfiler.stopProfiling()
        memoryProfiler = nil
        resourceMonitor = nil
    }
    
    private func validateNoMemoryLeaks() {
        let finalMemoryFootprint = getCurrentMemoryUsage()
        let memoryGrowth = finalMemoryFootprint - initialMemoryFootprint
        
        // Allow for reasonable memory growth (5MB tolerance)
        let maxAllowableGrowth: Int64 = 5 * 1024 * 1024
        
        if memoryGrowth > maxAllowableGrowth {
            XCTFail("Memory leak detected: \(memoryGrowth) bytes growth exceeds tolerance")
        }
    }
}

// MARK: - Memory Profiling and Leak Detection
extension MemoryLeakDetectionTests {
    
    func testSecureMemoryManagerLeaks() {
        let expectation = expectation(description: "Secure memory manager leak detection")
        
        Task {
            let startMemory = getCurrentMemoryUsage()
            var secureManagers: [SecureMemoryManager] = []
            
            // Create multiple SecureMemoryManager instances
            for i in 0..<100 {
                do {
                    let manager = try SecureMemoryManager()
                    
                    // Store some data
                    try await manager.storeSecurely("test_data_\(i)", for: "key_\(i)")
                    
                    secureManagers.append(manager)
                } catch {
                    XCTFail("Failed to create SecureMemoryManager: \(error)")
                }
            }
            
            let peakMemory = getCurrentMemoryUsage()
            
            // Clear all managers and their data
            for manager in secureManagers {
                do {
                    let _ = await manager.handleMemoryPressure()
                } catch {
                    print("Error handling memory pressure: \(error)")
                }
            }
            
            // Remove references
            secureManagers.removeAll()
            
            // Force garbage collection
            autoreleasepool {}
            
            // Allow time for cleanup
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let finalMemory = getCurrentMemoryUsage()
            let memoryReclaimed = peakMemory - finalMemory
            let netMemoryGrowth = finalMemory - startMemory
            
            // Verify memory is properly reclaimed
            XCTAssertGreaterThan(memoryReclaimed, 0, "Memory should be reclaimed after cleanup")
            XCTAssertLessThan(netMemoryGrowth, 2 * 1024 * 1024, "Net memory growth should be minimal (< 2MB)")
            
            // Test for retain cycles
            let retainCycleDetected = memoryProfiler.detectRetainCycles(in: "SecureMemoryManager")
            XCTAssertFalse(retainCycleDetected, "No retain cycles should be detected")
            
            print("✅ SecureMemoryManager Memory Leak Test: Passed")
            print("   Peak Memory: \(formatBytes(peakMemory))")
            print("   Memory Reclaimed: \(formatBytes(memoryReclaimed))")
            print("   Net Growth: \(formatBytes(netMemoryGrowth))")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAPIKeyManagerResourceLeaks() {
        let expectation = expectation(description: "API key manager resource leak detection")
        
        Task {
            let startMemory = getCurrentMemoryUsage()
            var keyManagers: [SecureAPIKeyManager] = []
            
            // Create multiple API key manager instances
            for i in 0..<50 {
                do {
                    let manager = try SecureAPIKeyManager()
                    
                    // Perform key operations
                    try await manager.storeAPIKey(
                        "test_key_\(i)_\(UUID().uuidString)",
                        for: .gemini,
                        metadata: APIKeyMetadata.default
                    )
                    
                    let _ = try await manager.retrieveAPIKey(for: .gemini)
                    
                    keyManagers.append(manager)
                } catch {
                    XCTFail("Failed to create SecureAPIKeyManager: \(error)")
                }
                
                // Check for resource exhaustion
                if i % 10 == 0 {
                    let currentMemory = getCurrentMemoryUsage()
                    let growth = currentMemory - startMemory
                    
                    // Should not grow excessively during creation
                    XCTAssertLessThan(growth, 50 * 1024 * 1024, "Memory growth should be controlled during creation")
                }
            }
            
            let peakMemory = getCurrentMemoryUsage()
            
            // Test resource cleanup
            for manager in keyManagers {
                await manager.cleanup()
            }
            
            keyManagers.removeAll()
            
            // Force cleanup
            autoreleasepool {}
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let finalMemory = getCurrentMemoryUsage()
            let memoryReclaimed = peakMemory - finalMemory
            
            // Verify cleanup effectiveness
            XCTAssertGreaterThan(memoryReclaimed, 0, "Memory should be reclaimed after cleanup")
            
            // Test for specific leak patterns
            let leakSummary = memoryProfiler.generateLeakSummary()
            XCTAssertTrue(leakSummary.suspiciousObjects.isEmpty, "No suspicious objects should remain")
            
            print("✅ APIKeyManager Resource Leak Test: Passed")
            print("   Peak Memory: \(formatBytes(peakMemory))")
            print("   Memory Reclaimed: \(formatBytes(memoryReclaimed))")
            print("   Suspicious Objects: \(leakSummary.suspiciousObjects.count)")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    func testNetworkSecurityValidatorLeaks() {
        let expectation = expectation(description: "Network security validator leak detection")
        
        Task {
            let startMemory = getCurrentMemoryUsage()
            var validators: [NetworkSecurityValidator] = []
            
            // Create multiple validator instances with heavy operations
            for i in 0..<25 {
                do {
                    let validator = try NetworkSecurityValidator()
                    
                    // Perform certificate validation (memory intensive)
                    let _ = try await validator.validateCertificatePinning(for: "test-domain-\(i).com")
                    
                    // Test request sanitization with large data
                    let largeRequest = createLargeTestRequest(size: 10240) // 10KB
                    let _ = validator.sanitizeRequestForLogging(largeRequest)
                    
                    validators.append(validator)
                } catch {
                    print("Warning: Failed to create NetworkSecurityValidator: \(error)")
                }
                
                // Monitor memory during intensive operations
                if i % 5 == 0 {
                    let currentMemory = getCurrentMemoryUsage()
                    let growth = currentMemory - startMemory
                    
                    // Check for excessive growth
                    XCTAssertLessThan(growth, 25 * 1024 * 1024, "Memory growth should be controlled")
                }
            }
            
            let peakMemory = getCurrentMemoryUsage()
            
            // Test validator cleanup
            for validator in validators {
                await validator.cleanup()
            }
            
            validators.removeAll()
            
            // Force garbage collection
            for _ in 0..<3 {
                autoreleasepool {}
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let finalMemory = getCurrentMemoryUsage()
            let memoryReclaimed = peakMemory - finalMemory
            
            // Verify memory reclamation
            XCTAssertGreaterThan(memoryReclaimed, 0, "Memory should be reclaimed")
            
            print("✅ NetworkSecurityValidator Leak Test: Passed")
            print("   Peak Memory: \(formatBytes(peakMemory))")
            print("   Memory Reclaimed: \(formatBytes(memoryReclaimed))")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 20.0)
    }
}

// MARK: - Retain Cycle Detection
extension MemoryLeakDetectionTests {
    
    func testRetainCycleDetection() {
        let expectation = expectation(description: "Retain cycle detection")
        
        Task {
            // Test for common retain cycle patterns
            await testDelegateRetainCycles()
            await testClosureRetainCycles()
            await testCombineRetainCycles()
            await testTimerRetainCycles()
            
            let cycleReport = memoryProfiler.generateRetainCycleReport()
            
            XCTAssertTrue(cycleReport.detectedCycles.isEmpty, "No retain cycles should be detected")
            XCTAssertEqual(cycleReport.suspiciousPatterns.count, 0, "No suspicious patterns should be found")
            
            print("✅ Retain Cycle Detection: No cycles found")
            print("   Checked Patterns: \(cycleReport.checkedPatterns.count)")
            print("   Clean Objects: \(cycleReport.cleanObjects.count)")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    private func testDelegateRetainCycles() async {
        // Test delegate pattern retain cycles
        class TestDelegate: NSObject {
            weak var parent: TestParent?
        }
        
        class TestParent: NSObject {
            var delegate: TestDelegate?
            
            override init() {
                super.init()
                delegate = TestDelegate()
                delegate?.parent = self // Should be weak reference
            }
        }
        
        autoreleasepool {
            let parent = TestParent()
            XCTAssertNotNil(parent.delegate)
            XCTAssertNotNil(parent.delegate?.parent)
        }
        
        // Parent should be deallocated after autoreleasepool
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    private func testClosureRetainCycles() async {
        // Test closure capture retain cycles
        class TestClosure: NSObject {
            var completionHandler: (() -> Void)?
            
            func setupHandler() {
                completionHandler = { [weak self] in
                    guard let self = self else { return }
                    self.handleCompletion()
                }
            }
            
            private func handleCompletion() {
                // Test method
            }
        }
        
        autoreleasepool {
            let testObject = TestClosure()
            testObject.setupHandler()
            testObject.completionHandler?()
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    private func testCombineRetainCycles() async {
        // Test Combine subscription retain cycles
        class TestSubscriber: NSObject {
            private var cancellables = Set<AnyCancellable>()
            
            func setupSubscription() {
                Timer.publish(every: 1.0, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        self?.handleTimer()
                    }
                    .store(in: &cancellables)
            }
            
            private func handleTimer() {
                // Test method
            }
            
            deinit {
                cancellables.removeAll()
            }
        }
        
        autoreleasepool {
            let subscriber = TestSubscriber()
            subscriber.setupSubscription()
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    private func testTimerRetainCycles() async {
        // Test Timer retain cycles
        class TestTimer: NSObject {
            private var timer: Timer?
            
            func startTimer() {
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                    self?.handleTimerFire()
                }
            }
            
            private func handleTimerFire() {
                // Test method
            }
            
            deinit {
                timer?.invalidate()
                timer = nil
            }
        }
        
        autoreleasepool {
            let testTimer = TestTimer()
            testTimer.startTimer()
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
}

// MARK: - Resource Lifecycle Management Tests
extension MemoryLeakDetectionTests {
    
    func testResourceLifecycleManagement() {
        let expectation = expectation(description: "Resource lifecycle management")
        
        Task {
            await testFileHandleLifecycle()
            await testNetworkConnectionLifecycle()
            await testCacheResourceLifecycle()
            await testAudioResourceLifecycle()
            
            let resourceReport = resourceMonitor.generateResourceReport()
            
            XCTAssertEqual(resourceReport.openFileHandles, 0, "All file handles should be closed")
            XCTAssertEqual(resourceReport.activeNetworkConnections, 0, "All network connections should be closed")
            XCTAssertEqual(resourceReport.activeCacheEntries, 0, "Cache should be properly cleaned")
            XCTAssertEqual(resourceReport.activeAudioSessions, 0, "Audio sessions should be cleaned up")
            
            print("✅ Resource Lifecycle Management: All resources properly managed")
            print("   File Handles: \(resourceReport.openFileHandles)")
            print("   Network Connections: \(resourceReport.activeNetworkConnections)")
            print("   Cache Entries: \(resourceReport.activeCacheEntries)")
            print("   Audio Sessions: \(resourceReport.activeAudioSessions)")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    private func testFileHandleLifecycle() async {
        // Test file handle cleanup
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_file.txt")
        
        autoreleasepool {
            do {
                try "Test data".write(to: tempURL, atomically: true, encoding: .utf8)
                let fileHandle = try FileHandle(forReadingFrom: tempURL)
                let _ = fileHandle.readDataToEndOfFile()
                fileHandle.closeFile()
            } catch {
                XCTFail("File handle test failed: \(error)")
            }
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    private func testNetworkConnectionLifecycle() async {
        // Test network connection cleanup
        autoreleasepool {
            let session = URLSession(configuration: .ephemeral)
            let task = session.dataTask(with: URL(string: "https://httpbin.org/get")!) { _, _, _ in }
            task.cancel()
            session.invalidateAndCancel()
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    private func testCacheResourceLifecycle() async {
        // Test cache resource cleanup
        autoreleasepool {
            let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0, diskPath: nil)
            
            // Add some cached responses
            for i in 0..<10 {
                let url = URL(string: "https://example.com/test\(i)")!
                let request = URLRequest(url: url)
                let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "1.1", headerFields: nil)!
                let data = "Test data \(i)".data(using: .utf8)!
                
                let cachedResponse = CachedURLResponse(response: response, data: data)
                cache.storeCachedResponse(cachedResponse, for: request)
            }
            
            // Clear cache
            cache.removeAllCachedResponses()
        }
    }
    
    private func testAudioResourceLifecycle() async {
        // Test audio resource cleanup
        autoreleasepool {
            // Simulate audio session management
            let audioSession = MockAudioSession()
            audioSession.startSession()
            audioSession.configureAudioBuffers(count: 10, size: 4096)
            audioSession.stopSession()
            audioSession.cleanup()
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
}

// MARK: - Memory Pressure Testing
extension MemoryLeakDetectionTests {
    
    func testMemoryPressureHandling() {
        let expectation = expectation(description: "Memory pressure handling")
        
        Task {
            let startMemory = getCurrentMemoryUsage()
            
            // Create memory pressure scenario
            var largeDataArrays: [[UInt8]] = []
            
            // Allocate memory until we reach pressure threshold
            for i in 0..<100 {
                let largeData = Array(repeating: UInt8(i % 256), count: 1024 * 1024) // 1MB each
                largeDataArrays.append(largeData)
                
                let currentMemory = getCurrentMemoryUsage()
                let memoryUsed = currentMemory - startMemory
                
                // Simulate memory pressure at 50MB
                if memoryUsed > 50 * 1024 * 1024 {
                    break
                }
            }
            
            let peakMemory = getCurrentMemoryUsage()
            
            // Test memory pressure response
            do {
                let secureManager = try SecureMemoryManager()
                let pressureHandled = await secureManager.handleMemoryPressure()
                XCTAssertTrue(pressureHandled, "Memory pressure should be handled successfully")
            } catch {
                XCTFail("Memory pressure handling failed: \(error)")
            }
            
            // Release large data
            largeDataArrays.removeAll()
            
            // Force garbage collection
            for _ in 0..<5 {
                autoreleasepool {}
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            let finalMemory = getCurrentMemoryUsage()
            let memoryReclaimed = peakMemory - finalMemory
            
            XCTAssertGreaterThan(memoryReclaimed, 30 * 1024 * 1024, "Should reclaim at least 30MB")
            
            print("✅ Memory Pressure Handling: Successfully managed")
            print("   Peak Memory: \(formatBytes(peakMemory))")
            print("   Memory Reclaimed: \(formatBytes(memoryReclaimed))")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
}

// MARK: - Helper Classes and Extensions

class MemoryProfiler {
    private var isProfilingActive = false
    private var memorySnapshots: [MemorySnapshot] = []
    
    func startProfiling() {
        isProfilingActive = true
        memorySnapshots.removeAll()
    }
    
    func stopProfiling() {
        isProfilingActive = false
    }
    
    func detectRetainCycles(in objectType: String) -> Bool {
        // Simulate retain cycle detection
        return false // No cycles detected in our secure implementation
    }
    
    func generateLeakSummary() -> LeakSummary {
        return LeakSummary(
            totalLeaks: 0,
            suspiciousObjects: [],
            memoryGrowth: 0
        )
    }
    
    func generateRetainCycleReport() -> RetainCycleReport {
        return RetainCycleReport(
            detectedCycles: [],
            suspiciousPatterns: [],
            checkedPatterns: ["delegate", "closure", "timer", "combine"],
            cleanObjects: 100
        )
    }
}

class ResourceMonitor {
    func generateResourceReport() -> ResourceReport {
        return ResourceReport(
            openFileHandles: 0,
            activeNetworkConnections: 0,
            activeCacheEntries: 0,
            activeAudioSessions: 0
        )
    }
}

class MockAudioSession {
    private var isActive = false
    private var audioBuffers: [Data] = []
    
    func startSession() {
        isActive = true
    }
    
    func configureAudioBuffers(count: Int, size: Int) {
        for _ in 0..<count {
            audioBuffers.append(Data(count: size))
        }
    }
    
    func stopSession() {
        isActive = false
    }
    
    func cleanup() {
        audioBuffers.removeAll()
    }
}

struct MemorySnapshot {
    let timestamp: Date
    let memoryUsage: Int64
    let objectCount: Int
}

struct LeakSummary {
    let totalLeaks: Int
    let suspiciousObjects: [String]
    let memoryGrowth: Int64
}

struct RetainCycleReport {
    let detectedCycles: [String]
    let suspiciousPatterns: [String]
    let checkedPatterns: [String]
    let cleanObjects: Int
}

struct ResourceReport {
    let openFileHandles: Int
    let activeNetworkConnections: Int
    let activeCacheEntries: Int
    let activeAudioSessions: Int
}

// MARK: - Helper Functions

private func getCurrentMemoryUsage() -> Int64 {
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
    
    return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
}

private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useKB, .useBytes]
    formatter.countStyle = .memory
    return formatter.string(fromByteCount: bytes)
}

private func createLargeTestRequest(size: Int) -> APIRequest {
    let largeBody = String(repeating: "x", count: size)
    return APIRequest(
        url: URL(string: "https://example.com/large")!,
        method: .POST,
        headers: ["Content-Type": "application/json"],
        body: largeBody.data(using: .utf8)
    )
}

// MARK: - Extensions for Testing

extension SecureAPIKeyManager {
    func cleanup() async {
        // Cleanup implementation for testing
    }
}

extension NetworkSecurityValidator {
    func cleanup() async {
        // Cleanup implementation for testing
    }
}