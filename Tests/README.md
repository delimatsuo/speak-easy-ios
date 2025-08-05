# Universal Translator Backend Test Suite

This comprehensive test suite provides complete testing coverage for the Universal Translator App backend systems, including Speech-to-Text (STT), Gemini 2.5 Pro API integration, and all supporting services.

## 🧪 Test Structure

### Test Categories

1. **Unit Tests** - Individual component testing in isolation
2. **Integration Tests** - End-to-end workflow and API integration testing
3. **Performance Tests** - Load testing, memory usage, and response time validation
4. **Security Tests** - API key management, network security, and privacy compliance
5. **Error Handling Tests** - Network failures, API errors, and recovery mechanisms

### Test Files

| File | Purpose | Test Count |
|------|---------|------------|
| `BackendTestPlan.md` | Comprehensive test planning documentation | - |
| `TestConfiguration.swift` | Test environment setup and configuration | - |
| `MockServices.swift` | Mock implementations for all external services | - |
| `SpeechRecognitionTests.swift` | Speech recognition and audio processing tests | ~25 |
| `GeminiAPITests.swift` | Gemini API integration and TTS tests | ~20 |
| `SecurityTests.swift` | Security, privacy, and API key management tests | ~15 |
| `PerformanceTests.swift` | Performance, memory, and stress tests | ~18 |
| `ErrorHandlingTests.swift` | Error scenarios and recovery testing | ~22 |
| `TestSuite.swift` | Test execution coordinator and reporting | - |

## 🚀 Quick Start

### Running Tests

```swift
// Run all tests
let testSuite = UniversalTranslatorTestSuite.shared
let results = await testSuite.runFullTestSuite()

// Run specific test categories
let unitResults = await testSuite.runUnitTests()
let integrationResults = await testSuite.runIntegrationTests()
let performanceResults = await testSuite.runPerformanceTests()
let errorResults = await testSuite.runErrorHandlingTests()

// Run critical tests only (for CI/CD)
let criticalResults = await testSuite.runCriticalTests()
```

### CI/CD Integration

```swift
// For CI/CD environments
let cicdResults = await testSuite.runCICDTests()
let report = testSuite.generateTestReport(cicdResults)
```

## 📋 Test Coverage

### Speech Recognition Testing
- ✅ Multi-language recognition (15+ languages)
- ✅ Audio processing and noise filtering
- ✅ Silence detection (configurable 0.5-2.0s)
- ✅ Confidence score validation (0.0-1.0)
- ✅ Real-time transcription performance
- ✅ Language detection with 70%+ confidence
- ✅ Permission handling and error recovery

### Gemini API Integration Testing
- ✅ Translation API endpoint connectivity
- ✅ Request/response structure validation
- ✅ Rate limiting (60 RPM) compliance
- ✅ Exponential backoff with jitter (±10%)
- ✅ Character limit enforcement (10,000 chars)
- ✅ TTS API functionality and voice selection
- ✅ Audio encoding validation (MP3, 24kHz)
- ✅ Error response handling (401, 429, 5xx)

### Security Testing
- ✅ API key storage in keychain
- ✅ Secure key retrieval and rotation
- ✅ TLS 1.3 enforcement
- ✅ Certificate pinning validation
- ✅ Data privacy controls
- ✅ User consent mechanisms
- ✅ Data deletion functionality
- ✅ Memory security for sensitive data

### Performance Testing
- ✅ Concurrent translation operations
- ✅ Memory usage under load (<100MB)
- ✅ Response time benchmarks (<2s translation)
- ✅ Cache performance and hit rates
- ✅ Resource contention handling
- ✅ Thread safety validation
- ✅ Extended operation sessions (30s+)
- ✅ High-frequency API calls (1000+ requests)

### Error Handling Testing
- ✅ Network timeout recovery
- ✅ Connection loss handling
- ✅ Offline mode graceful degradation
- ✅ Request queuing during outages
- ✅ Rate limit exceeded recovery
- ✅ Speech recognition errors
- ✅ Permission denial handling
- ✅ Circuit breaker pattern implementation

## 🎯 Critical Test Scenarios

### Must-Pass Tests
1. **End-to-End Translation Pipeline**
   - Speech → Text → Translation → Audio
   - Target: <3s total latency

2. **API Rate Limiting Compliance**
   - 60 requests per minute maximum
   - Exponential backoff on failures

3. **Secure API Key Management**
   - Keychain storage/retrieval
   - No keys in logs or memory dumps

4. **Offline Mode Functionality**
   - Cache-based translation fallback
   - Graceful service degradation

5. **Memory Efficiency**
   - <100MB peak usage
   - No memory leaks in long sessions

## 📊 Test Metrics

### Performance Targets
- **Translation Latency**: <2.0s
- **STT Latency**: <1.0s
- **TTS Latency**: <3.0s
- **Memory Usage**: <100MB peak
- **Code Coverage**: 90%+
- **Test Execution Time**: <10 minutes full suite

### Quality Thresholds
- **Success Rate**: ≥95% for critical tests
- **Unit Test Coverage**: ≥90%
- **Integration Test Coverage**: ≥80%
- **Performance Regression**: <10% degradation

## 🛠 Test Configuration

### Environment Setup
```swift
struct TestConfiguration {
    static let mockAPIBaseURL = "https://mock-api.test"
    static let testAPIKey = "test_api_key_12345"
    static let testTimeout: TimeInterval = 10.0
    static let maxRetryAttempts = 3
    static let maxCacheSize = 10 * 1024 * 1024  // 10MB
    static let testSilenceThreshold: TimeInterval = 0.5
}
```

### Mock Services
- **MockGeminiAPI**: Simulates Gemini API responses
- **MockSpeechRecognizer**: Provides test speech recognition results
- **MockNetworkService**: Controls network connectivity simulation
- **MockCacheManager**: Memory and disk cache simulation
- **MockLanguageDetector**: Language detection testing

## 📈 Continuous Integration

### CI/CD Pipeline Integration
1. **Pre-commit**: Run unit tests (<2 minutes)
2. **Pull Request**: Run critical tests (~5 minutes)
3. **Merge**: Run full test suite (~10 minutes)
4. **Release**: Run extended stress tests (~30 minutes)

### Test Reports
- JUnit XML format for CI integration
- HTML reports with detailed metrics
- Performance trend analysis
- Security scan results

## 🔧 Advanced Testing

### Stress Testing Scenarios
- **High Concurrency**: 50+ simultaneous operations
- **Extended Sessions**: 30+ minute continuous operation
- **Memory Pressure**: Large text processing (9KB+ inputs)
- **Resource Exhaustion**: CPU and memory limit testing

### Security Testing Scenarios
- **API Key Rotation**: Seamless key updates
- **Certificate Pinning**: MITM attack prevention
- **Data Sanitization**: No sensitive data in logs
- **Privacy Compliance**: GDPR-style data deletion

## 📚 Usage Examples

### Basic Test Execution
```swift
import XCTest

class MyTestCase: BaseTestCase {
    func testTranslationWorkflow() async {
        let result = await expectAsync {
            return try await translateText("Hello", from: "en", to: "es")
        }
        
        XCTAssertEqual(result, "Hola")
    }
}
```

### Performance Testing
```swift
class MyPerformanceTest: PerformanceTestCase {
    func testTranslationLatency() {
        measureAsyncPerformance {
            _ = try await translateText("Hello world")
        }
    }
}
```

### Mock Configuration
```swift
override func setUp() {
    super.setUp()
    
    // Configure mock API responses
    MockGeminiAPI.shared.setTranslationResponse(
        for: "Hello", 
        response: "Hola"
    )
    
    // Simulate network conditions
    MockNetworkService.shared.simulateLatency(0.5)
}
```

## 🐛 Troubleshooting

### Common Issues
1. **Test Timeouts**: Increase `TestConfiguration.testTimeout`
2. **Mock Setup**: Ensure `setUp()` calls `super.setUp()`
3. **Memory Leaks**: Use `autoreleasepool` in performance tests
4. **Async Testing**: Use `expectAsync` helper for async operations

### Debug Mode
Enable verbose logging by setting:
```swift
TestConfiguration.debugMode = true
```

## 📝 Contributing

### Adding New Tests
1. Create test class inheriting from `BaseTestCase`
2. Follow naming convention: `ComponentNameTests`
3. Include setup/teardown for mock services
4. Add performance benchmarks where applicable
5. Update test count in README

### Test Guidelines
- **Isolation**: Each test should be independent
- **Deterministic**: Tests should produce consistent results
- **Fast**: Unit tests should complete in <100ms
- **Clear**: Test names should describe the scenario
- **Comprehensive**: Cover happy path, edge cases, and errors

---

**Version**: 1.0  
**Last Updated**: 2025-08-03  
**Compatibility**: iOS 15.0+, Swift 5.5+  
**Test Framework**: XCTest  
**Total Test Count**: ~100 tests