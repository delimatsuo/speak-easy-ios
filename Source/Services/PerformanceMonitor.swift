import Foundation
import Combine

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var currentMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published var isMonitoring: Bool = false
    
    private var metrics: [PerformanceRecord] = []
    private let maxRecords = 1000
    private let metricsQueue = DispatchQueue(label: "performance.metrics.queue")
    private var updateTimer: Timer?
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        Task { @MainActor in
            self.isMonitoring = true
        }
        
        // Start periodic metrics collection with weak reference
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateCurrentMetrics()
        }
        
        print("Performance monitoring started")
    }
    
    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
        
        Task { @MainActor in
            self.isMonitoring = false
        }
        
        print("Performance monitoring stopped")
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Recording Methods
    
    func recordAPICall(
        endpoint: String,
        method: String,
        duration: TimeInterval,
        responseSize: Int,
        statusCode: Int,
        error: Error? = nil
    ) {
        let record = PerformanceRecord(
            timestamp: Date(),
            type: .apiCall,
            operation: "\(method) \(endpoint)",
            duration: duration,
            dataSize: responseSize,
            statusCode: statusCode,
            error: error,
            metadata: [
                "endpoint": endpoint,
                "method": method,
                "responseSize": responseSize,
                "statusCode": statusCode
            ]
        )
        
        addRecord(record)
    }
    
    func recordTranslation(
        sourceLanguage: String,
        targetLanguage: String,
        textLength: Int,
        duration: TimeInterval,
        confidence: Float,
        cached: Bool = false
    ) {
        let record = PerformanceRecord(
            timestamp: Date(),
            type: .translation,
            operation: "translate",
            duration: duration,
            dataSize: textLength,
            confidence: confidence,
            metadata: [
                "sourceLanguage": sourceLanguage,
                "targetLanguage": targetLanguage,
                "textLength": textLength,
                "confidence": confidence,
                "cached": cached
            ]
        )
        
        addRecord(record)
    }
    
    func recordSpeechRecognition(
        language: String,
        duration: TimeInterval,
        confidence: Float,
        textLength: Int,
        isFinal: Bool
    ) {
        let record = PerformanceRecord(
            timestamp: Date(),
            type: .speechRecognition,
            operation: "recognize",
            duration: duration,
            dataSize: textLength,
            confidence: confidence,
            metadata: [
                "language": language,
                "textLength": textLength,
                "confidence": confidence,
                "isFinal": isFinal
            ]
        )
        
        addRecord(record)
    }
    
    func recordTTS(
        language: String,
        textLength: Int,
        duration: TimeInterval,
        audioSize: Int
    ) {
        let record = PerformanceRecord(
            timestamp: Date(),
            type: .tts,
            operation: "synthesize",
            duration: duration,
            dataSize: audioSize,
            metadata: [
                "language": language,
                "textLength": textLength,
                "audioSize": audioSize
            ]
        )
        
        addRecord(record)
    }
    
    func recordUIOperation(
        operation: String,
        duration: TimeInterval,
        frameDrops: Int = 0
    ) {
        let record = PerformanceRecord(
            timestamp: Date(),
            type: .ui,
            operation: operation,
            duration: duration,
            metadata: [
                "operation": operation,
                "frameDrops": frameDrops
            ]
        )
        
        addRecord(record)
    }
    
    func recordTranslationComplete(
        duration: TimeInterval,
        textLength: Int,
        success: Bool,
        error: Error? = nil
    ) {
        let record = PerformanceRecord(
            timestamp: Date(),
            type: .translation,
            operation: "complete_translation",
            duration: duration,
            dataSize: textLength,
            error: error,
            metadata: [
                "textLength": textLength,
                "success": success
            ]
        )
        
        addRecord(record)
    }
    
    func recordCacheOperation(
        operation: String,
        duration: TimeInterval,
        dataSize: Int,
        hit: Bool
    ) {
        let record = PerformanceRecord(
            timestamp: Date(),
            type: .cache,
            operation: operation,
            duration: duration,
            dataSize: dataSize,
            metadata: [
                "operation": operation,
                "dataSize": dataSize,
                "hit": hit
            ]
        )
        
        addRecord(record)
    }
    
    private func addRecord(_ record: PerformanceRecord) {
        metricsQueue.async {
            self.metrics.append(record)
            
            // Maintain max records limit
            if self.metrics.count > self.maxRecords {
                self.metrics.removeFirst(self.metrics.count - self.maxRecords)
            }
        }
    }
    
    // MARK: - Analytics Methods
    
    func getMetrics(for type: PerformanceType, since: Date? = nil) -> [PerformanceRecord] {
        return metricsQueue.sync {
            let filtered = metrics.filter { record in
                record.type == type && (since == nil || record.timestamp >= since!)
            }
            return filtered
        }
    }
    
    func getAverageResponseTime(for operation: String, since: Date? = nil) -> TimeInterval {
        let records = metricsQueue.sync {
            metrics.filter { record in
                record.operation == operation && (since == nil || record.timestamp >= since!)
            }
        }
        
        guard !records.isEmpty else { return 0 }
        
        let totalTime = records.reduce(0) { $0 + $1.duration }
        return totalTime / Double(records.count)
    }
    
    func getErrorRate(for operation: String, since: Date? = nil) -> Double {
        let records = metricsQueue.sync {
            metrics.filter { record in
                record.operation == operation && (since == nil || record.timestamp >= since!)
            }
        }
        
        guard !records.isEmpty else { return 0 }
        
        let errorCount = records.filter { $0.error != nil }.count
        return Double(errorCount) / Double(records.count)
    }
    
    func getCacheHitRate(since: Date? = nil) -> Double {
        let cacheRecords = getMetrics(for: .cache, since: since)
        guard !cacheRecords.isEmpty else { return 0 }
        
        let hits = cacheRecords.filter { record in
            record.metadata["hit"] as? Bool == true
        }.count
        
        return Double(hits) / Double(cacheRecords.count)
    }
    
    private func updateCurrentMetrics() {
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        
        let recentRecords = metricsQueue.sync {
            metrics.filter { $0.timestamp >= oneHourAgo }
        }
        
        let apiRecords = recentRecords.filter { $0.type == .apiCall }
        let translationRecords = recentRecords.filter { $0.type == .translation }
        
        let newMetrics = PerformanceMetrics(
            averageAPIResponseTime: calculateAverage(apiRecords.map { $0.duration }),
            averageTranslationTime: calculateAverage(translationRecords.map { $0.duration }),
            apiErrorRate: calculateErrorRate(apiRecords),
            cacheHitRate: getCacheHitRate(since: oneHourAgo),
            totalRequestsLastHour: apiRecords.count,
            averageConfidence: calculateAverage(translationRecords.compactMap { $0.confidence }),
            lastUpdated: now
        )
        
        Task { @MainActor in
            self.currentMetrics = newMetrics
        }
    }
    
    private func calculateAverage(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    private func calculateAverage(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Float(values.count)
    }
    
    private func calculateErrorRate(_ records: [PerformanceRecord]) -> Double {
        guard !records.isEmpty else { return 0 }
        let errorCount = records.filter { $0.error != nil }.count
        return Double(errorCount) / Double(records.count)
    }
    
    // MARK: - Reporting
    
    func generateReport(since: Date? = nil) -> PerformanceReport {
        let sinceDate = since ?? Date().addingTimeInterval(-24 * 3600) // Last 24 hours
        
        let recentRecords = metricsQueue.sync {
            metrics.filter { $0.timestamp >= sinceDate }
        }
        
        return PerformanceReport(
            timeRange: sinceDate...Date(),
            totalOperations: recentRecords.count,
            apiCalls: recentRecords.filter { $0.type == .apiCall }.count,
            translations: recentRecords.filter { $0.type == .translation }.count,
            speechRecognitions: recentRecords.filter { $0.type == .speechRecognition }.count,
            ttsOperations: recentRecords.filter { $0.type == .tts }.count,
            averageResponseTime: calculateAverage(recentRecords.map { $0.duration }),
            errorRate: calculateErrorRate(recentRecords),
            cacheHitRate: getCacheHitRate(since: sinceDate),
            peakResponseTime: recentRecords.map { $0.duration }.max() ?? 0,
            averageConfidence: calculateAverage(recentRecords.compactMap { $0.confidence })
        )
    }
    
    func exportMetrics() -> String {
        let report = generateReport()
        
        return """
        Performance Report
        ==================
        Time Range: \(report.timeRange.lowerBound) - \(report.timeRange.upperBound)
        
        Operations:
        - Total: \(report.totalOperations)
        - API Calls: \(report.apiCalls)
        - Translations: \(report.translations)
        - Speech Recognition: \(report.speechRecognitions)
        - TTS: \(report.ttsOperations)
        
        Performance:
        - Average Response Time: \(String(format: "%.2f", report.averageResponseTime))s
        - Peak Response Time: \(String(format: "%.2f", report.peakResponseTime))s
        - Error Rate: \(String(format: "%.1f", report.errorRate * 100))%
        - Cache Hit Rate: \(String(format: "%.1f", report.cacheHitRate * 100))%
        - Average Confidence: \(String(format: "%.2f", report.averageConfidence))
        """
    }
}

// MARK: - Supporting Types

struct PerformanceRecord {
    let timestamp: Date
    let type: PerformanceType
    let operation: String
    let duration: TimeInterval
    let dataSize: Int
    let statusCode: Int?
    let confidence: Float?
    let error: Error?
    let metadata: [String: Any]
    
    init(
        timestamp: Date,
        type: PerformanceType,
        operation: String,
        duration: TimeInterval,
        dataSize: Int = 0,
        statusCode: Int? = nil,
        confidence: Float? = nil,
        error: Error? = nil,
        metadata: [String: Any] = [:]
    ) {
        self.timestamp = timestamp
        self.type = type
        self.operation = operation
        self.duration = duration
        self.dataSize = dataSize
        self.statusCode = statusCode
        self.confidence = confidence
        self.error = error
        self.metadata = metadata
    }
}

enum PerformanceType {
    case apiCall
    case translation
    case speechRecognition
    case tts
    case cache
    case ui
}

struct PerformanceMetrics {
    let averageAPIResponseTime: Double
    let averageTranslationTime: Double
    let apiErrorRate: Double
    let cacheHitRate: Double
    let totalRequestsLastHour: Int
    let averageConfidence: Float
    let lastUpdated: Date
    
    init() {
        self.averageAPIResponseTime = 0
        self.averageTranslationTime = 0
        self.apiErrorRate = 0
        self.cacheHitRate = 0
        self.totalRequestsLastHour = 0
        self.averageConfidence = 0
        self.lastUpdated = Date()
    }
    
    init(
        averageAPIResponseTime: Double,
        averageTranslationTime: Double,
        apiErrorRate: Double,
        cacheHitRate: Double,
        totalRequestsLastHour: Int,
        averageConfidence: Float,
        lastUpdated: Date
    ) {
        self.averageAPIResponseTime = averageAPIResponseTime
        self.averageTranslationTime = averageTranslationTime
        self.apiErrorRate = apiErrorRate
        self.cacheHitRate = cacheHitRate
        self.totalRequestsLastHour = totalRequestsLastHour
        self.averageConfidence = averageConfidence
        self.lastUpdated = lastUpdated
    }
}

struct PerformanceReport {
    let timeRange: ClosedRange<Date>
    let totalOperations: Int
    let apiCalls: Int
    let translations: Int
    let speechRecognitions: Int
    let ttsOperations: Int
    let averageResponseTime: Double
    let errorRate: Double
    let cacheHitRate: Double
    let peakResponseTime: Double
    let averageConfidence: Float
}