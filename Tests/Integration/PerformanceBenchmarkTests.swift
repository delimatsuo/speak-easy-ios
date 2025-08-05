import XCTest
import Foundation
@testable import UniversalTranslatorApp

// MARK: - Performance Benchmarking and Load Testing
class PerformanceBenchmarkTests: PerformanceTestCase {
    
    var benchmarkSuite: PerformanceBenchmarkSuite!
    var loadTestManager: LoadTestManager!
    var metricCollector: PerformanceMetricCollector!
    
    override func setUp() {
        super.setUp()
        setupPerformanceComponents()
    }
    
    override func tearDown() {
        teardownPerformanceComponents()
        super.tearDown()
    }
    
    private func setupPerformanceComponents() {
        benchmarkSuite = PerformanceBenchmarkSuite()
        loadTestManager = LoadTestManager()
        metricCollector = PerformanceMetricCollector()
    }
    
    private func teardownPerformanceComponents() {
        benchmarkSuite = nil
        loadTestManager = nil
        metricCollector = nil
    }
    
    // MARK: - Translation Pipeline Benchmarks
    
    func testTranslationPipelineBenchmark() {
        let expectation = expectation(description: "Translation pipeline benchmark")
        
        Task {
            let benchmarkConfig = BenchmarkConfiguration(
                iterations: 100,
                warmupIterations: 10,
                timeout: 30.0,
                collectDetailedMetrics: true
            )
            
            let results = await benchmarkSuite.runTranslationPipelineBenchmark(config: benchmarkConfig)
            
            // Validate performance metrics
            XCTAssertLessThan(results.averageLatency, 3.0, "Average translation latency should be <3s")
            XCTAssertLessThan(results.p95Latency, 5.0, "95th percentile latency should be <5s")
            XCTAssertLessThan(results.p99Latency, 8.0, "99th percentile latency should be <8s")
            
            XCTAssertLessThan(results.averageMemoryUsage, 100 * 1024 * 1024, "Average memory usage should be <100MB")
            XCTAssertLessThan(results.peakMemoryUsage, 150 * 1024 * 1024, "Peak memory usage should be <150MB")
            
            XCTAssertGreaterThan(results.successRate, 0.95, "Success rate should be >95%")
            
            print("📊 Translation Pipeline Benchmark Results:")
            print("   Average Latency: \(String(format: "%.2f", results.averageLatency))s")
            print("   P95 Latency: \(String(format: "%.2f", results.p95Latency))s")
            print("   P99 Latency: \(String(format: "%.2f", results.p99Latency))s")
            print("   Success Rate: \(String(format: "%.1f", results.successRate * 100))%")
            print("   Peak Memory: \(results.peakMemoryUsage / 1024 / 1024)MB")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 45.0)
    }
    
    func testSpeechRecognitionPerformanceBenchmark() {
        let expectation = expectation(description: "Speech recognition performance benchmark")
        
        measureAsyncPerformance {
            let testAudioSamples = await self.generateTestAudioSamples(count: 50)
            var processingTimes: [TimeInterval] = []
            
            for audioSample in testAudioSamples {
                let startTime = Date()
                
                do {
                    _ = try await self.benchmarkSuite.processSpeechRecognition(audioSample)
                    let processingTime = Date().timeIntervalSince(startTime)
                    processingTimes.append(processingTime)
                } catch {
                    XCTFail("Speech recognition failed: \(error)")
                }
            }
            
            let averageTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
            XCTAssertLessThan(averageTime, 1.0, "Average speech recognition time should be <1s")
            
            print("🎤 Speech Recognition Benchmark: \(String(format: "%.3f", averageTime))s average")
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    func testTextToSpeechPerformanceBenchmark() {
        let expectation = expectation(description: "TTS performance benchmark")
        
        Task {
            let testTexts = [
                "Hello, this is a short test.",
                "This is a medium length text that contains multiple sentences and should take a bit longer to process.",
                """
                This is a very long text that contains multiple paragraphs and sentences.
                It should test the performance of the text-to-speech system with longer content.
                The system should handle this efficiently while maintaining good audio quality.
                Performance metrics should remain within acceptable limits even for longer texts.
                """
            ]
            
            var ttsBenchmarkResults: [TTSBenchmarkResult] = []
            
            for (index, text) in testTexts.enumerated() {
                let startTime = Date()
                
                do {
                    let audioData = try await benchmarkSuite.processTextToSpeech(
                        text: text,
                        language: "en-US"
                    )
                    
                    let processingTime = Date().timeIntervalSince(startTime)
                    let audioSizeKB = audioData.count / 1024
                    let charactersPerSecond = Double(text.count) / processingTime
                    
                    let result = TTSBenchmarkResult(
                        textLength: text.count,
                        processingTime: processingTime,
                        audioSizeKB: audioSizeKB,
                        charactersPerSecond: charactersPerSecond
                    )
                    
                    ttsBenchmarkResults.append(result)
                    
                    // Performance validation
                    XCTAssertLessThan(processingTime, 5.0, "TTS processing should be <5s for text \(index)")
                    XCTAssertGreaterThan(charactersPerSecond, 20.0, "Should process >20 chars/second")
                    XCTAssertGreaterThan(audioSizeKB, 1, "Should generate substantial audio data")
                    
                } catch {
                    XCTFail("TTS processing failed for text \(index): \(error)")
                }
            }
            
            // Analyze performance scaling
            if ttsBenchmarkResults.count >= 2 {
                let efficiency = analyzePerformanceScaling(ttsBenchmarkResults)
                XCTAssertGreaterThan(efficiency, 0.7, "TTS scaling efficiency should be >70%")
            }
            
            print("🔊 TTS Benchmark Results:")
            for (index, result) in ttsBenchmarkResults.enumerated() {
                print("   Text \(index): \(result.textLength) chars in \(String(format: "%.2f", result.processingTime))s (\(String(format: "%.1f", result.charactersPerSecond)) chars/s)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Load Testing
    
    func testConcurrentTranslationLoad() {
        let expectation = expectation(description: "Concurrent translation load test")
        
        Task {
            let loadTestConfig = LoadTestConfiguration(
                concurrentUsers: 25,
                requestsPerUser: 10,
                rampUpTime: 5.0,
                testDuration: 60.0,
                requestTimeout: 10.0
            )
            
            let loadTestResults = await loadTestManager.runConcurrentTranslationTest(config: loadTestConfig)
            
            // Validate load test results
            XCTAssertGreaterThan(loadTestResults.successRate, 0.90, "Success rate should be >90% under load")
            XCTAssertLessThan(loadTestResults.averageResponseTime, 5.0, "Average response time should be <5s under load")
            XCTAssertLessThan(loadTestResults.errorRate, 0.10, "Error rate should be <10% under load")
            
            // Performance degradation should be acceptable
            let degradationFactor = loadTestResults.averageResponseTime / loadTestResults.baselineResponseTime
            XCTAssertLessThan(degradationFactor, 3.0, "Performance degradation should be <3x baseline")
            
            print("🏋️ Load Test Results:")
            print("   Concurrent Users: \(loadTestConfig.concurrentUsers)")
            print("   Total Requests: \(loadTestResults.totalRequests)")
            print("   Success Rate: \(String(format: "%.1f", loadTestResults.successRate * 100))%")
            print("   Average Response Time: \(String(format: "%.2f", loadTestResults.averageResponseTime))s")
            print("   Error Rate: \(String(format: "%.1f", loadTestResults.errorRate * 100))%")
            print("   Throughput: \(String(format: "%.1f", loadTestResults.throughput)) req/s")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 120.0)
    }
    
    func testMemoryStressTest() {
        let expectation = expectation(description: "Memory stress test")
        
        Task {
            let initialMemory = await metricCollector.getCurrentMemoryUsage()
            
            // Simulate high memory usage scenario
            let stressTestConfig = MemoryStressTestConfiguration(
                largeTextCount: 100,
                audioBufferCount: 50,
                cacheSize: 10 * 1024 * 1024, // 10MB
                duration: 30.0
            )
            
            let stressResults = await loadTestManager.runMemoryStressTest(config: stressTestConfig)
            
            // Validate memory behavior
            XCTAssertLessThan(stressResults.peakMemoryUsage, 200 * 1024 * 1024, "Peak memory should be <200MB")
            XCTAssertLessThan(stressResults.memoryLeakage, 10 * 1024 * 1024, "Memory leakage should be <10MB")
            XCTAssertTrue(stressResults.memoryRecovered, "Memory should be recovered after stress test")
            
            let finalMemory = await metricCollector.getCurrentMemoryUsage()
            let memoryIncrease = finalMemory - initialMemory
            
            XCTAssertLessThan(memoryIncrease, 20 * 1024 * 1024, "Memory increase should be <20MB after test")
            
            print("🧠 Memory Stress Test Results:")
            print("   Initial Memory: \(initialMemory / 1024 / 1024)MB")
            print("   Peak Memory: \(stressResults.peakMemoryUsage / 1024 / 1024)MB")
            print("   Final Memory: \(finalMemory / 1024 / 1024)MB")
            print("   Memory Leakage: \(stressResults.memoryLeakage / 1024 / 1024)MB")
            print("   Memory Recovered: \(stressResults.memoryRecovered)")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    func testAPIRateLimitStressTest() {
        let expectation = expectation(description: "API rate limit stress test")
        
        Task {
            let rateLimitConfig = RateLimitTestConfiguration(
                requestsPerSecond: 10,
                burstSize: 20,
                testDuration: 30.0,
                expectedRateLimit: 60 // per minute
            )
            
            let rateLimitResults = await loadTestManager.runRateLimitStressTest(config: rateLimitConfig)
            
            // Validate rate limiting behavior
            XCTAssertTrue(rateLimitResults.rateLimitDetected, "Rate limiting should be detected")
            XCTAssertGreaterThan(rateLimitResults.successfulRequestsBeforeLimit, 50, "Should allow reasonable number of requests")
            XCTAssertLessThan(rateLimitResults.averageRetryDelay, 10.0, "Average retry delay should be reasonable")
            
            // Retry mechanism validation
            XCTAssertGreaterThan(rateLimitResults.retrySuccessRate, 0.80, "Retry success rate should be >80%")
            
            print("⚡ Rate Limit Stress Test Results:")
            print("   Rate Limit Detected: \(rateLimitResults.rateLimitDetected)")
            print("   Successful Requests Before Limit: \(rateLimitResults.successfulRequestsBeforeLimit)")
            print("   Total Rate Limited Requests: \(rateLimitResults.rateLimitedRequests)")
            print("   Retry Success Rate: \(String(format: "%.1f", rateLimitResults.retrySuccessRate * 100))%")
            print("   Average Retry Delay: \(String(format: "%.2f", rateLimitResults.averageRetryDelay))s")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    // MARK: - Performance Regression Testing
    
    func testPerformanceRegression() {
        let expectation = expectation(description: "Performance regression test")
        
        Task {
            let baselineBenchmark = await loadBaselinePerformanceMetrics()
            let currentBenchmark = await benchmarkSuite.runCurrentPerformanceBenchmark()
            
            let regressionAnalysis = analyzePerformanceRegression(
                baseline: baselineBenchmark,
                current: currentBenchmark
            )
            
            // Validate no significant regression
            XCTAssertLessThan(regressionAnalysis.latencyRegression, 0.20, "Latency regression should be <20%")
            XCTAssertLessThan(regressionAnalysis.memoryRegression, 0.15, "Memory regression should be <15%")
            XCTAssertLessThan(regressionAnalysis.throughputRegression, 0.10, "Throughput regression should be <10%")
            
            // Log regression analysis
            print("📉 Performance Regression Analysis:")
            print("   Latency Change: \(String(format: "%+.1f", regressionAnalysis.latencyRegression * 100))%")
            print("   Memory Change: \(String(format: "%+.1f", regressionAnalysis.memoryRegression * 100))%")
            print("   Throughput Change: \(String(format: "%+.1f", regressionAnalysis.throughputRegression * 100))%")
            
            if regressionAnalysis.hasSignificantRegression {
                print("⚠️ Significant performance regression detected!")
                
                // Generate regression report
                let regressionReport = generateRegressionReport(regressionAnalysis)
                print(regressionReport)
            } else {
                print("✅ No significant performance regression detected")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Helper Methods
    
    private func generateTestAudioSamples(count: Int) async -> [AudioSample] {
        var samples: [AudioSample] = []
        
        for i in 0..<count {
            let sample = AudioSample(
                duration: Double.random(in: 1.0...5.0),
                text: "Test audio sample \(i) with varying content length",
                language: "en-US"
            )
            samples.append(sample)
        }
        
        return samples
    }
    
    private func analyzePerformanceScaling(_ results: [TTSBenchmarkResult]) -> Double {
        // Calculate performance scaling efficiency
        guard results.count >= 2 else { return 1.0 }
        
        let shortestResult = results.min(by: { $0.textLength < $1.textLength })!
        let longestResult = results.max(by: { $0.textLength < $1.textLength })!
        
        let lengthRatio = Double(longestResult.textLength) / Double(shortestResult.textLength)
        let timeRatio = longestResult.processingTime / shortestResult.processingTime
        
        // Ideal scaling would be linear (timeRatio == lengthRatio)
        return min(1.0, lengthRatio / timeRatio)
    }
    
    private func loadBaselinePerformanceMetrics() async -> PerformanceBenchmark {
        // In real implementation, this would load saved baseline metrics
        return PerformanceBenchmark(
            averageLatency: 2.1,
            p95Latency: 3.8,
            averageMemory: 75 * 1024 * 1024,
            throughput: 12.5,
            successRate: 0.97
        )
    }
    
    private func analyzePerformanceRegression(baseline: PerformanceBenchmark, current: PerformanceBenchmark) -> RegressionAnalysis {
        let latencyRegression = (current.averageLatency - baseline.averageLatency) / baseline.averageLatency
        let memoryRegression = (Double(current.averageMemory - baseline.averageMemory)) / Double(baseline.averageMemory)
        let throughputRegression = (baseline.throughput - current.throughput) / baseline.throughput
        
        let hasSignificantRegression = latencyRegression > 0.15 || memoryRegression > 0.10 || throughputRegression > 0.05
        
        return RegressionAnalysis(
            latencyRegression: latencyRegression,
            memoryRegression: memoryRegression,
            throughputRegression: throughputRegression,
            hasSignificantRegression: hasSignificantRegression
        )
    }
    
    private func generateRegressionReport(_ analysis: RegressionAnalysis) -> String {
        return """
        
        🚨 PERFORMANCE REGRESSION REPORT
        ================================
        
        Regression Details:
        - Latency increased by \(String(format: "%.1f", analysis.latencyRegression * 100))%
        - Memory usage increased by \(String(format: "%.1f", analysis.memoryRegression * 100))%
        - Throughput decreased by \(String(format: "%.1f", analysis.throughputRegression * 100))%
        
        Recommended Actions:
        1. Review recent code changes
        2. Profile memory usage patterns
        3. Analyze algorithm complexity changes
        4. Check for resource leaks
        
        """
    }
}

// MARK: - Supporting Data Structures and Classes

struct BenchmarkConfiguration {
    let iterations: Int
    let warmupIterations: Int
    let timeout: TimeInterval
    let collectDetailedMetrics: Bool
}

struct BenchmarkResults {
    let averageLatency: TimeInterval
    let p95Latency: TimeInterval
    let p99Latency: TimeInterval
    let averageMemoryUsage: Int64
    let peakMemoryUsage: Int64
    let successRate: Double
    let throughput: Double
}

struct TTSBenchmarkResult {
    let textLength: Int
    let processingTime: TimeInterval
    let audioSizeKB: Int
    let charactersPerSecond: Double
}

struct LoadTestConfiguration {
    let concurrentUsers: Int
    let requestsPerUser: Int
    let rampUpTime: TimeInterval
    let testDuration: TimeInterval
    let requestTimeout: TimeInterval
}

struct LoadTestResults {
    let totalRequests: Int
    let successRate: Double
    let averageResponseTime: TimeInterval
    let baselineResponseTime: TimeInterval
    let errorRate: Double
    let throughput: Double
}

struct MemoryStressTestConfiguration {
    let largeTextCount: Int
    let audioBufferCount: Int
    let cacheSize: Int
    let duration: TimeInterval
}

struct MemoryStressTestResults {
    let peakMemoryUsage: Int64
    let memoryLeakage: Int64
    let memoryRecovered: Bool
}

struct RateLimitTestConfiguration {
    let requestsPerSecond: Int
    let burstSize: Int
    let testDuration: TimeInterval
    let expectedRateLimit: Int
}

struct RateLimitTestResults {
    let rateLimitDetected: Bool
    let successfulRequestsBeforeLimit: Int
    let rateLimitedRequests: Int
    let retrySuccessRate: Double
    let averageRetryDelay: TimeInterval
}

struct PerformanceBenchmark {
    let averageLatency: TimeInterval
    let p95Latency: TimeInterval
    let averageMemory: Int64
    let throughput: Double
    let successRate: Double
}

struct RegressionAnalysis {
    let latencyRegression: Double
    let memoryRegression: Double
    let throughputRegression: Double
    let hasSignificantRegression: Bool
}

struct AudioSample {
    let duration: TimeInterval
    let text: String
    let language: String
}

// MARK: - Performance Test Implementation Classes

class PerformanceBenchmarkSuite {
    
    func runTranslationPipelineBenchmark(config: BenchmarkConfiguration) async -> BenchmarkResults {
        var latencies: [TimeInterval] = []
        var memoryUsages: [Int64] = []
        var successes = 0
        
        // Warmup
        for _ in 0..<config.warmupIterations {
            _ = try? await processTestTranslation()
        }
        
        // Actual benchmark
        for i in 0..<config.iterations {
            let startTime = Date()
            let startMemory = getCurrentMemoryUsage()
            
            do {
                _ = try await processTestTranslation()
                successes += 1
            } catch {
                // Record failure
            }
            
            let latency = Date().timeIntervalSince(startTime)
            let endMemory = getCurrentMemoryUsage()
            
            latencies.append(latency)
            memoryUsages.append(endMemory)
            
            // Brief pause between iterations
            if i < config.iterations - 1 {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        
        return BenchmarkResults(
            averageLatency: latencies.reduce(0, +) / Double(latencies.count),
            p95Latency: calculatePercentile(latencies, percentile: 0.95),
            p99Latency: calculatePercentile(latencies, percentile: 0.99),
            averageMemoryUsage: memoryUsages.reduce(0, +) / Int64(memoryUsages.count),
            peakMemoryUsage: memoryUsages.max() ?? 0,
            successRate: Double(successes) / Double(config.iterations),
            throughput: Double(successes) / (latencies.reduce(0, +))
        )
    }
    
    func processSpeechRecognition(_ audioSample: AudioSample) async throws -> String {
        // Simulate speech recognition processing
        let processingDelay = audioSample.duration * 0.3 // 30% of audio duration
        try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        
        return "Recognized: \(audioSample.text)"
    }
    
    func processTextToSpeech(text: String, language: String) async throws -> Data {
        // Simulate TTS processing time based on text length
        let processingTime = Double(text.count) * 0.01 + 0.5 // Base 500ms + 10ms per character
        try await Task.sleep(nanoseconds: UInt64(processingTime * 1_000_000_000))
        
        // Generate mock audio data
        let audioSize = text.count * 50 // ~50 bytes per character for audio
        return Data(repeating: 0xFF, count: audioSize)
    }
    
    func runCurrentPerformanceBenchmark() async -> PerformanceBenchmark {
        let config = BenchmarkConfiguration(
            iterations: 50,
            warmupIterations: 5,
            timeout: 20.0,
            collectDetailedMetrics: false
        )
        
        let results = await runTranslationPipelineBenchmark(config: config)
        
        return PerformanceBenchmark(
            averageLatency: results.averageLatency,
            p95Latency: results.p95Latency,
            averageMemory: results.averageMemoryUsage,
            throughput: results.throughput,
            successRate: results.successRate
        )
    }
    
    private func processTestTranslation() async throws -> String {
        // Simulate translation pipeline
        try await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.5...3.0) * 1_000_000_000))
        
        // Simulate occasional failures
        if Double.random(in: 0...1) < 0.05 { // 5% failure rate
            throw BenchmarkError.simulatedFailure
        }
        
        return "Translation result"
    }
    
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
    
    private func calculatePercentile(_ values: [TimeInterval], percentile: Double) -> TimeInterval {
        let sorted = values.sorted()
        let index = Int(Double(sorted.count - 1) * percentile)
        return sorted[index]
    }
}

class LoadTestManager {
    
    func runConcurrentTranslationTest(config: LoadTestConfiguration) async -> LoadTestResults {
        var totalRequests = 0
        var successfulRequests = 0
        var responseTimes: [TimeInterval] = []
        let baselineTime: TimeInterval = 2.0 // Baseline single-user response time
        
        // Ramp up users gradually
        let usersPerStep = max(1, config.concurrentUsers / 5)
        let rampStepDelay = config.rampUpTime / 5.0
        
        await withTaskGroup(of: [TimeInterval].self) { group in
            for step in 0..<5 {
                let usersInStep = min(usersPerStep, config.concurrentUsers - step * usersPerStep)
                
                for userIndex in 0..<usersInStep {
                    group.addTask {
                        return await self.simulateUserRequests(
                            requestCount: config.requestsPerUser,
                            timeout: config.requestTimeout
                        )
                    }
                }
                
                // Ramp up delay
                if step < 4 {
                    try? await Task.sleep(nanoseconds: UInt64(rampStepDelay * 1_000_000_000))
                }
            }
            
            // Collect results
            for await userResults in group {
                totalRequests += config.requestsPerUser
                successfulRequests += userResults.count
                responseTimes.append(contentsOf: userResults)
            }
        }
        
        let averageResponseTime = responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count)
        let successRate = Double(successfulRequests) / Double(totalRequests)
        let errorRate = 1.0 - successRate
        let throughput = Double(successfulRequests) / config.testDuration
        
        return LoadTestResults(
            totalRequests: totalRequests,
            successRate: successRate,
            averageResponseTime: averageResponseTime,
            baselineResponseTime: baselineTime,
            errorRate: errorRate,
            throughput: throughput
        )
    }
    
    func runMemoryStressTest(config: MemoryStressTestConfiguration) async -> MemoryStressTestResults {
        let initialMemory = getCurrentMemoryUsage()
        var peakMemory = initialMemory
        
        // Simulate memory-intensive operations
        var largeObjects: [Data] = []
        
        // Create large text objects
        for i in 0..<config.largeTextCount {
            let largeText = String(repeating: "Memory stress test data \(i) ", count: 1000)
            largeObjects.append(largeText.data(using: .utf8)!)
        }
        
        // Create audio buffers
        for i in 0..<config.audioBufferCount {
            let audioData = Data(repeating: UInt8(i % 256), count: 44100 * 2) // 1 second of audio
            largeObjects.append(audioData)
        }
        
        // Monitor peak memory
        let monitoringTask = Task {
            while !Task.isCancelled {
                let currentMemory = getCurrentMemoryUsage()
                peakMemory = max(peakMemory, currentMemory)
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        
        // Wait for test duration
        try? await Task.sleep(nanoseconds: UInt64(config.duration * 1_000_000_000))
        
        monitoringTask.cancel()
        
        // Clean up and measure recovery
        largeObjects.removeAll()
        
        // Force garbage collection
        autoreleasepool { }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second for cleanup
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryLeakage = max(0, finalMemory - initialMemory)
        let memoryRecovered = finalMemory < (peakMemory * 0.8) // 80% memory should be recovered
        
        return MemoryStressTestResults(
            peakMemoryUsage: peakMemory,
            memoryLeakage: memoryLeakage,
            memoryRecovered: memoryRecovered
        )
    }
    
    func runRateLimitStressTest(config: RateLimitTestConfiguration) async -> RateLimitTestResults {
        var successfulRequests = 0
        var rateLimitedRequests = 0
        var retryDelays: [TimeInterval] = []
        var retrySuccesses = 0
        var rateLimitDetected = false
        
        let requestInterval = 1.0 / Double(config.requestsPerSecond)
        let endTime = Date().addingTimeInterval(config.testDuration)
        
        while Date() < endTime {
            let requestStart = Date()
            
            do {
                // Simulate API request
                try await simulateAPIRequest()
                successfulRequests += 1
                
                if rateLimitDetected && successfulRequests > 0 {
                    retrySuccesses += 1
                }
                
            } catch APITestError.rateLimited {
                rateLimitedRequests += 1
                rateLimitDetected = true
                
                // Implement retry with exponential backoff
                let retryDelay = min(pow(2.0, Double(rateLimitedRequests % 5)), 16.0)
                retryDelays.append(retryDelay)
                
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
            
            // Maintain request rate
            let elapsed = Date().timeIntervalSince(requestStart)
            let remainingInterval = requestInterval - elapsed
            if remainingInterval > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingInterval * 1_000_000_000))
            }
        }
        
        let averageRetryDelay = retryDelays.isEmpty ? 0 : retryDelays.reduce(0, +) / Double(retryDelays.count)
        let retrySuccessRate = rateLimitedRequests > 0 ? Double(retrySuccesses) / Double(rateLimitedRequests) : 1.0
        
        return RateLimitTestResults(
            rateLimitDetected: rateLimitDetected,
            successfulRequestsBeforeLimit: successfulRequests,
            rateLimitedRequests: rateLimitedRequests,
            retrySuccessRate: retrySuccessRate,
            averageRetryDelay: averageRetryDelay
        )
    }
    
    private func simulateUserRequests(requestCount: Int, timeout: TimeInterval) async -> [TimeInterval] {
        var responseTimes: [TimeInterval] = []
        
        for _ in 0..<requestCount {
            let startTime = Date()
            
            do {
                try await simulateTranslationRequest(timeout: timeout)
                let responseTime = Date().timeIntervalSince(startTime)
                responseTimes.append(responseTime)
            } catch {
                // Request failed - don't add to response times
            }
            
            // Small delay between requests from same user
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        
        return responseTimes
    }
    
    private func simulateTranslationRequest(timeout: TimeInterval) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                // Simulate actual translation work
                let processingTime = Double.random(in: 0.5...4.0) // Varied response times
                try await Task.sleep(nanoseconds: UInt64(processingTime * 1_000_000_000))
                
                // Simulate occasional failures
                if Double.random(in: 0...1) < 0.08 { // 8% failure rate under load
                    throw APITestError.serviceUnavailable
                }
            }
            
            group.addTask {
                // Timeout task
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw APITestError.timeout
            }
            
            try await group.next()
            group.cancelAll()
        }
    }
    
    private func simulateAPIRequest() async throws {
        // Simulate rate limiting after certain number of requests
        let requestCount = Int.random(in: 50...70) // Simulate rate limit after 50-70 requests
        
        if Int.random(in: 1...100) <= requestCount {
            throw APITestError.rateLimited
        }
        
        // Simulate normal processing
        try await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.1...0.5) * 1_000_000_000))
    }
    
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
}

class PerformanceMetricCollector {
    func getCurrentMemoryUsage() async -> Int64 {
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

enum BenchmarkError: Error {
    case simulatedFailure
    case timeout
}

enum APITestError: Error {
    case rateLimited
    case serviceUnavailable
    case timeout
}