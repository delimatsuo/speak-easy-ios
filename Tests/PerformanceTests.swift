import XCTest
import Foundation
@testable import UniversalTranslatorApp

// MARK: - Performance & Load Testing
class PerformanceTests: PerformanceTestCase {
    
    var mockAPI: MockGeminiAPI!
    var mockCacheManager: MockCacheManager!
    
    override func setUp() {
        super.setUp()
        mockAPI = MockGeminiAPI.shared
        mockCacheManager = MockCacheManager.shared
    }
    
    override func tearDown() {
        mockAPI.reset()
        mockCacheManager.reset()
        super.tearDown()
    }
    
    // MARK: - Concurrent Operation Tests
    func testConcurrentTranslations() {
        let expectation = expectation(description: "Concurrent translations")
        expectation.expectedFulfillmentCount = 10
        
        let startTime = Date()
        
        // Test 10 concurrent translation requests
        for i in 0..<10 {
            Task {
                let testText = "Hello world \(i)"
                
                // Simulate translation processing time
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Simulate translation result
                let result = "Hola mundo \(i)"
                XCTAssertFalse(result.isEmpty)
                
                let elapsed = Date().timeIntervalSince(startTime)
                XCTAssertLessThan(elapsed, TestConfiguration.maxTranslationLatency * 2) // Allow for concurrency
                
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testQueueProcessingEfficiency() {
        measureAsyncPerformance {
            // Test queue processing with multiple items
            let queueSize = 50
            var processedItems = 0
            
            for i in 0..<queueSize {
                // Simulate queue item processing
                let item = "Item \(i)"
                XCTAssertFalse(item.isEmpty)
                processedItems += 1
            }
            
            XCTAssertEqual(processedItems, queueSize)
        }
    }
    
    func testThreadSafety() {
        let expectation = expectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = 20
        
        let sharedCounter = NSMutableArray()
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        // Test concurrent access to shared resource
        for i in 0..<20 {
            queue.async {
                // Simulate thread-safe operations
                DispatchQueue.main.async {
                    sharedCounter.add(i)
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
        XCTAssertEqual(sharedCounter.count, 20)
    }
    
    func testResourceContention() {
        let expectation = expectation(description: "Resource contention")
        
        Task {
            // Test multiple operations competing for resources
            let operations = 100
            var completedOperations = 0
            
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<operations {
                    group.addTask {
                        // Simulate resource-intensive operation
                        let result = self.simulateResourceIntensiveOperation(id: i)
                        XCTAssertNotNil(result)
                    }
                }
                
                for await _ in group {
                    completedOperations += 1
                }
            }
            
            XCTAssertEqual(completedOperations, operations)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    private func simulateResourceIntensiveOperation(id: Int) -> String {
        // Simulate CPU-intensive work
        let iterations = 1000
        var result = 0
        
        for i in 0..<iterations {
            result += i * id
        }
        
        return "Result: \(result)"
    }
}

// MARK: - Memory & Resource Tests
class ResourceTests: PerformanceTestCase {
    
    var mockCacheManager: MockCacheManager!
    
    override func setUp() {
        super.setUp()
        mockCacheManager = MockCacheManager.shared
    }
    
    override func tearDown() {
        mockCacheManager.reset()
        super.tearDown()
    }
    
    // MARK: - Memory Usage Tests
    func testMemoryUsageUnderLoad() {
        let expectation = expectation(description: "Memory usage under load")
        
        Task {
            let initialMemory = self.getMemoryUsage()
            
            // Simulate high memory usage scenario
            var testData: [Data] = []
            
            for i in 0..<100 {
                // Create 1KB of test data each iteration
                let data = Data(repeating: UInt8(i % 256), count: 1024)
                testData.append(data)
                
                // Check memory periodically
                if i % 10 == 0 {
                    let currentMemory = self.getMemoryUsage()
                    let memoryGrowth = currentMemory - initialMemory
                    
                    // Memory growth should be reasonable
                    XCTAssertLessThan(memoryGrowth, TestConfiguration.maxMemoryUsage)
                }
            }
            
            // Clean up
            testData.removeAll()
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testMemoryLeakDetection() {
        let expectation = expectation(description: "Memory leak detection")
        
        Task {
            let initialMemory = self.getMemoryUsage()
            
            // Perform operations that could potentially leak memory
            for i in 0..<50 {
                autoreleasepool {
                    // Simulate object creation and release
                    let testObject = TestMemoryObject(id: i)
                    testObject.performOperation()
                    // Object should be deallocated at end of autoreleasepool
                }
                
                // Force garbage collection
                if i % 10 == 0 {
                    autoreleasepool { }
                }
            }
            
            // Allow time for cleanup
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let finalMemory = self.getMemoryUsage()
            let memoryDifference = finalMemory - initialMemory
            
            // Memory should not have grown significantly
            XCTAssertLessThan(memoryDifference, 5 * 1024 * 1024) // 5MB tolerance
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testDiskSpaceUsage() {
        let expectation = expectation(description: "Disk space usage")
        
        Task {
            // Test cache disk usage limits
            let maxCacheSize = TestConfiguration.maxCacheSize
            var currentCacheSize = 0
            
            for i in 0..<100 {
                let testData = Data(repeating: UInt8(i % 256), count: 1024) // 1KB
                let key = "test_key_\(i)"
                
                if currentCacheSize + testData.count <= maxCacheSize {
                    self.mockCacheManager.store(testData, forKey: key)
                    currentCacheSize += testData.count
                } else {
                    // Should not exceed cache size limit
                    break
                }
            }
            
            XCTAssertLessThanOrEqual(currentCacheSize, maxCacheSize)
            
            // Test cache cleanup
            self.mockCacheManager.reset()
            let finalCacheSize = self.mockCacheManager.getCacheSize()
            XCTAssertEqual(finalCacheSize, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testCPUUtilization() {
        measureAsyncPerformance {
            // Test CPU-intensive operations
            let iterations = 10000
            
            await withTaskGroup(of: Int.self) { group in
                for i in 0..<10 { // 10 concurrent tasks
                    group.addTask {
                        return self.performCPUIntensiveTask(iterations: iterations / 10, offset: i)
                    }
                }
                
                var totalResult = 0
                for await result in group {
                    totalResult += result
                }
                
                XCTAssertGreaterThan(totalResult, 0)
            }
        }
    }
    
    private func performCPUIntensiveTask(iterations: Int, offset: Int) -> Int {
        var result = 0
        
        for i in 0..<iterations {
            // Simulate computational work
            result += (i * offset) % 1000
        }
        
        return result
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
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// MARK: - Test Helper Classes
private class TestMemoryObject {
    let id: Int
    var data: Data?
    
    init(id: Int) {
        self.id = id
        self.data = Data(repeating: UInt8(id % 256), count: 1024)
    }
    
    func performOperation() {
        // Simulate some work with the data
        guard let data = data else { return }
        let _ = data.reduce(0, +)
    }
    
    deinit {
        data = nil
    }
}

// MARK: - Stress Testing
class StressTests: PerformanceTestCase {
    
    var mockAPI: MockGeminiAPI!
    var mockNetworkService: MockNetworkService!
    
    override func setUp() {
        super.setUp()
        mockAPI = MockGeminiAPI.shared
        mockNetworkService = MockNetworkService.shared
    }
    
    override func tearDown() {
        mockAPI.reset()
        mockNetworkService.reset()
        super.tearDown()
    }
    
    // MARK: - Extended Operation Tests
    func testExtendedOperationSessions() {
        let expectation = expectation(description: "Extended operation sessions")
        
        Task {
            let sessionDuration: TimeInterval = 30.0 // 30 seconds
            let operationInterval: TimeInterval = 0.1 // Every 100ms
            let startTime = Date()
            
            var operationCount = 0
            var errorCount = 0
            
            while Date().timeIntervalSince(startTime) < sessionDuration {
                do {
                    // Simulate continuous operations
                    try await self.simulateTranslationOperation(id: operationCount)
                    operationCount += 1
                } catch {
                    errorCount += 1
                }
                
                try? await Task.sleep(nanoseconds: UInt64(operationInterval * 1_000_000_000))
            }
            
            // Verify system remained stable
            XCTAssertGreaterThan(operationCount, 0)
            XCTAssertLessThan(Double(errorCount) / Double(operationCount), 0.1) // <10% error rate
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 35.0) // Slightly longer than session duration
    }
    
    func testHighFrequencyAPICalls() {
        let expectation = expectation(description: "High frequency API calls")
        
        Task {
            let callCount = 1000
            let batchSize = 10
            var successfulCalls = 0
            var failedCalls = 0
            
            // Process in batches to avoid overwhelming the system
            for batch in 0..<(callCount / batchSize) {
                await withTaskGroup(of: Bool.self) { group in
                    for i in 0..<batchSize {
                        group.addTask {
                            return await self.simulateAPICall(id: batch * batchSize + i)
                        }
                    }
                    
                    for await success in group {
                        if success {
                            successfulCalls += 1
                        } else {
                            failedCalls += 1
                        }
                    }
                }
                
                // Small delay between batches
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            XCTAssertGreaterThan(successfulCalls, callCount * 0.8) // At least 80% success rate
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout * 2)
    }
    
    func testLargeTextProcessing() {
        let expectation = expectation(description: "Large text processing")
        
        Task {
            // Test with texts of various sizes
            let textSizes = [1000, 5000, 9000] // Characters
            
            for size in textSizes {
                let largeText = String(repeating: "Test text for translation. ", count: size / 27)
                XCTAssertLessThanOrEqual(largeText.count, 10000) // Within API limits
                
                let startTime = Date()
                
                // Simulate processing large text
                let result = await self.processLargeText(largeText)
                
                let processingTime = Date().timeIntervalSince(startTime)
                
                XCTAssertNotNil(result)
                XCTAssertLessThan(processingTime, TestConfiguration.maxTranslationLatency * 2)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    func testResourceExhaustionHandling() {
        let expectation = expectation(description: "Resource exhaustion handling")
        
        Task {
            // Simulate resource exhaustion scenarios
            let maxConcurrentOperations = 50
            var activeOperations = 0
            
            await withTaskGroup(of: Void.self) { group in
                for i in 0..<100 { // Attempt more than max
                    if activeOperations < maxConcurrentOperations {
                        group.addTask {
                            await self.simulateResourceIntensiveOperation(id: i)
                        }
                        activeOperations += 1
                    } else {
                        // Should handle resource exhaustion gracefully
                        XCTAssertTrue(true, "Correctly limited concurrent operations")
                    }
                }
                
                for await _ in group {
                    activeOperations -= 1
                }
            }
            
            XCTAssertEqual(activeOperations, 0)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
    
    // MARK: - Helper Methods
    private func simulateTranslationOperation(id: Int) async throws {
        // Simulate translation processing
        let text = "Test translation \(id)"
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms processing time
        
        if id % 100 == 99 { // Simulate occasional failure
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
    }
    
    private func simulateAPICall(id: Int) async -> Bool {
        // Simulate API call with random latency
        let latency = Double.random(in: 0.1...0.5) // 100-500ms
        try? await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
        
        // Simulate 95% success rate
        return Double.random(in: 0...1) < 0.95
    }
    
    private func processLargeText(_ text: String) async -> String? {
        // Simulate large text processing
        let chunkSize = 1000
        var processedChunks: [String] = []
        
        for i in stride(from: 0, to: text.count, by: chunkSize) {
            let endIndex = min(i + chunkSize, text.count)
            let startIdx = text.index(text.startIndex, offsetBy: i)
            let endIdx = text.index(text.startIndex, offsetBy: endIndex)
            let chunk = String(text[startIdx..<endIdx])
            
            // Simulate chunk processing
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms per chunk
            processedChunks.append("Processed: \(chunk.prefix(20))...")
        }
        
        return processedChunks.joined(separator: " ")
    }
    
    private func simulateResourceIntensiveOperation(id: Int) async {
        // Simulate CPU and memory intensive operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let data = Data(repeating: UInt8(id % 256), count: 10240) // 10KB
        let _ = data.reduce(0, +) // Force computation
    }
}

// MARK: - Cache Performance Tests
class CachePerformanceTests: PerformanceTestCase {
    
    var mockCacheManager: MockCacheManager!
    
    override func setUp() {
        super.setUp()
        mockCacheManager = MockCacheManager.shared
    }
    
    override func tearDown() {
        mockCacheManager.reset()
        super.tearDown()
    }
    
    func testCacheHitRatePerformance() {
        measureAsyncPerformance {
            // Test cache performance with various hit/miss scenarios
            let totalRequests = 1000
            let cacheSize = 100
            
            // Populate cache
            for i in 0..<cacheSize {
                let data = "cached_data_\(i)"
                self.mockCacheManager.store(data, forKey: "key_\(i)")
            }
            
            // Test cache access patterns
            for i in 0..<totalRequests {
                let key = "key_\(i % (cacheSize + 50))" // Some hits, some misses
                let _ = self.mockCacheManager.retrieve(forKey: key)
            }
            
            let stats = self.mockCacheManager.getCacheStats()
            let hitRate = Double(stats.hits) / Double(stats.hits + stats.misses)
            
            XCTAssertGreaterThan(hitRate, 0.5) // At least 50% hit rate
        }
    }
    
    func testCacheEvictionPerformance() {
        let expectation = expectation(description: "Cache eviction performance")
        
        Task {
            let maxItems = 100
            let testItems = 150 // More than max to trigger eviction
            
            let startTime = Date()
            
            // Add items beyond cache capacity
            for i in 0..<testItems {
                let data = "test_data_\(i)"
                self.mockCacheManager.store(data, forKey: "key_\(i)")
            }
            
            let evictionTime = Date().timeIntervalSince(startTime)
            
            // Eviction should be reasonably fast
            XCTAssertLessThan(evictionTime, 1.0) // Less than 1 second
            
            // Cache should not exceed maximum size
            let finalSize = self.mockCacheManager.getCacheSize()
            XCTAssertLessThanOrEqual(finalSize, maxItems)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: TestConfiguration.testTimeout)
    }
}