import Foundation
import os.log

/// Enterprise-grade centralized error handling framework
public class ErrorHandlingFramework {
    
    // MARK: - Singleton
    
    public static let shared = ErrorHandlingFramework()
    private init() {
        setupLogging()
    }
    
    // MARK: - Error Categories
    
    public enum ErrorCategory: String, CaseIterable {
        case authentication = "AUTHENTICATION"
        case authorization = "AUTHORIZATION"
        case validation = "VALIDATION"
        case security = "SECURITY"
        case network = "NETWORK"
        case database = "DATABASE"
        case business = "BUSINESS"
        case system = "SYSTEM"
        case external = "EXTERNAL"
        case unknown = "UNKNOWN"
        
        var priority: ErrorPriority {
            switch self {
            case .security, .authentication:
                return .critical
            case .authorization, .database:
                return .high
            case .validation, .business:
                return .medium
            case .network, .external:
                return .low
            case .system, .unknown:
                return .medium
            }
        }
    }
    
    public enum ErrorPriority: Int, Comparable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        public static func < (lhs: ErrorPriority, rhs: ErrorPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Error Context
    
    public struct ErrorContext {
        public let userID: String?
        public let sessionID: String?
        public let requestID: String?
        public let endpoint: String?
        public let userAgent: String?
        public let ipAddress: String?
        public let timestamp: Date
        public let additionalInfo: [String: Any]
        
        public init(
            userID: String? = nil,
            sessionID: String? = nil,
            requestID: String? = nil,
            endpoint: String? = nil,
            userAgent: String? = nil,
            ipAddress: String? = nil,
            timestamp: Date = Date(),
            additionalInfo: [String: Any] = [:]
        ) {
            self.userID = userID
            self.sessionID = sessionID
            self.requestID = requestID
            self.endpoint = endpoint
            self.userAgent = userAgent
            self.ipAddress = ipAddress
            self.timestamp = timestamp
            self.additionalInfo = additionalInfo
        }
    }
    
    // MARK: - Structured Error
    
    public struct StructuredError: Error {
        public let id: String
        public let category: ErrorCategory
        public let code: String
        public let message: String
        public let userMessage: String
        public let priority: ErrorPriority
        public let context: ErrorContext
        public let underlyingError: Error?
        public let stackTrace: String?
        public let remediation: String?
        
        public init(
            id: String = UUID().uuidString,
            category: ErrorCategory,
            code: String,
            message: String,
            userMessage: String,
            priority: ErrorPriority? = nil,
            context: ErrorContext = ErrorContext(),
            underlyingError: Error? = nil,
            stackTrace: String? = nil,
            remediation: String? = nil
        ) {
            self.id = id
            self.category = category
            self.code = code
            self.message = message
            self.userMessage = userMessage
            self.priority = priority ?? category.priority
            self.context = context
            self.underlyingError = underlyingError
            self.stackTrace = stackTrace ?? Thread.callStackSymbols.joined(separator: "\n")
            self.remediation = remediation
        }
    }
    
    // MARK: - Error Response
    
    public struct ErrorResponse: Codable {
        public let error: ErrorInfo
        public let requestId: String?
        public let timestamp: String
        
        public init(structuredError: StructuredError) {
            self.error = ErrorInfo(
                code: structuredError.code,
                message: structuredError.userMessage,
                category: structuredError.category.rawValue,
                details: structuredError.remediation
            )
            self.requestId = structuredError.context.requestID
            self.timestamp = ISO8601DateFormatter().string(from: structuredError.context.timestamp)
        }
    }
    
    public struct ErrorInfo: Codable {
        public let code: String
        public let message: String
        public let category: String
        public let details: String?
        
        public init(code: String, message: String, category: String, details: String? = nil) {
            self.code = code
            self.message = message
            self.category = category
            self.details = details
        }
    }
    
    // MARK: - Properties
    
    private let logger: OSLog
    private let queue = DispatchQueue(label: "error.handling", qos: .utility)
    private var errorHandlers: [ErrorCategory: [(StructuredError) -> Void]] = [:]
    private var errorMetrics: [String: ErrorMetrics] = [:]
    private let metricsQueue = DispatchQueue(label: "error.metrics", qos: .utility)
    
    // Configuration
    private var isLoggingEnabled = true
    private var isMetricsEnabled = true
    private var shouldSendAlerts = true
    private var maxErrorHistory = 10000
    
    // MARK: - Setup
    
    private func setupLogging() {
        logger = OSLog(subsystem: "com.universaltranslator.app", category: "ErrorHandling")
    }
    
    // MARK: - Error Handling
    
    /// Handles an error with full context and processing
    @discardableResult
    public func handle(
        category: ErrorCategory,
        code: String,
        message: String,
        userMessage: String,
        context: ErrorContext = ErrorContext(),
        underlyingError: Error? = nil,
        remediation: String? = nil
    ) -> StructuredError {
        
        let structuredError = StructuredError(
            category: category,
            code: code,
            message: message,
            userMessage: userMessage,
            context: context,
            underlyingError: underlyingError,
            remediation: remediation
        )
        
        processError(structuredError)
        return structuredError
    }
    
    /// Handles a raw error by converting it to structured format
    @discardableResult
    public func handle(
        error: Error,
        category: ErrorCategory = .unknown,
        context: ErrorContext = ErrorContext(),
        userMessage: String? = nil
    ) -> StructuredError {
        
        let code = String(describing: type(of: error))
        let message = error.localizedDescription
        let finalUserMessage = userMessage ?? generateUserFriendlyMessage(for: category)
        
        let structuredError = StructuredError(
            category: category,
            code: code,
            message: message,
            userMessage: finalUserMessage,
            context: context,
            underlyingError: error
        )
        
        processError(structuredError)
        return structuredError
    }
    
    /// Processes a structured error through the framework
    private func processError(_ error: StructuredError) {
        queue.async {
            // Log the error
            if self.isLoggingEnabled {
                self.logError(error)
            }
            
            // Update metrics
            if self.isMetricsEnabled {
                self.updateMetrics(error)
            }
            
            // Trigger handlers
            self.triggerHandlers(error)
            
            // Send alerts for critical errors
            if self.shouldSendAlerts && error.priority >= .high {
                self.sendAlert(error)
            }
        }
    }
    
    // MARK: - Logging
    
    private func logError(_ error: StructuredError) {
        let logLevel = osLogType(for: error.priority)
        
        let logMessage = """
        [ERROR] \(error.category.rawValue):\(error.code)
        ID: \(error.id)
        Message: \(error.message)
        User ID: \(error.context.userID ?? "N/A")
        Session ID: \(error.context.sessionID ?? "N/A")
        Request ID: \(error.context.requestID ?? "N/A")
        Endpoint: \(error.context.endpoint ?? "N/A")
        IP: \(error.context.ipAddress ?? "N/A")
        Timestamp: \(error.context.timestamp)
        """
        
        os_log("%@", log: logger, type: logLevel, logMessage)
        
        // Log stack trace for critical errors
        if error.priority == .critical, let stackTrace = error.stackTrace {
            os_log("Stack Trace: %@", log: logger, type: .fault, stackTrace)
        }
        
        // Log underlying error if present
        if let underlyingError = error.underlyingError {
            os_log("Underlying Error: %@", log: logger, type: logLevel, underlyingError.localizedDescription)
        }
    }
    
    private func osLogType(for priority: ErrorPriority) -> OSLogType {
        switch priority {
        case .low:
            return .info
        case .medium:
            return .default
        case .high:
            return .error
        case .critical:
            return .fault
        }
    }
    
    // MARK: - Metrics
    
    private struct ErrorMetrics {
        var count: Int = 0
        var lastOccurrence: Date = Date()
        var firstOccurrence: Date = Date()
        var averageFrequency: TimeInterval = 0
        
        mutating func update() {
            let now = Date()
            if count == 0 {
                firstOccurrence = now
            }
            count += 1
            
            if count > 1 {
                averageFrequency = now.timeIntervalSince(firstOccurrence) / TimeInterval(count - 1)
            }
            
            lastOccurrence = now
        }
    }
    
    private func updateMetrics(_ error: StructuredError) {
        metricsQueue.async {
            let key = "\(error.category.rawValue):\(error.code)"
            
            if var metrics = self.errorMetrics[key] {
                metrics.update()
                self.errorMetrics[key] = metrics
            } else {
                var newMetrics = ErrorMetrics()
                newMetrics.update()
                self.errorMetrics[key] = newMetrics
            }
        }
    }
    
    // MARK: - Handler Management
    
    /// Registers an error handler for a specific category
    public func addHandler(for category: ErrorCategory, handler: @escaping (StructuredError) -> Void) {
        queue.async(flags: .barrier) {
            if self.errorHandlers[category] == nil {
                self.errorHandlers[category] = []
            }
            self.errorHandlers[category]?.append(handler)
        }
    }
    
    /// Removes all handlers for a category
    public func removeHandlers(for category: ErrorCategory) {
        queue.async(flags: .barrier) {
            self.errorHandlers[category] = []
        }
    }
    
    private func triggerHandlers(_ error: StructuredError) {
        if let handlers = errorHandlers[error.category] {
            for handler in handlers {
                handler(error)
            }
        }
        
        // Also trigger handlers for 'unknown' category as fallback
        if error.category != .unknown, let fallbackHandlers = errorHandlers[.unknown] {
            for handler in fallbackHandlers {
                handler(error)
            }
        }
    }
    
    // MARK: - Alert System
    
    private func sendAlert(_ error: StructuredError) {
        // This would integrate with your alerting system (Slack, PagerDuty, etc.)
        // For now, we'll log a high-priority alert
        let alertMessage = """
        🚨 CRITICAL ERROR ALERT 🚨
        Category: \(error.category.rawValue)
        Code: \(error.code)
        Message: \(error.message)
        User ID: \(error.context.userID ?? "N/A")
        Endpoint: \(error.context.endpoint ?? "N/A")
        Time: \(error.context.timestamp)
        Remediation: \(error.remediation ?? "None provided")
        """
        
        os_log("🚨 %@", log: logger, type: .fault, alertMessage)
        
        // TODO: Integrate with external alerting systems
        // - Send to Slack/Teams
        // - Create PagerDuty incident
        // - Send email notifications
        // - Push to monitoring dashboard
    }
    
    // MARK: - User-Friendly Messages
    
    private func generateUserFriendlyMessage(for category: ErrorCategory) -> String {
        switch category {
        case .authentication:
            return "Authentication failed. Please check your credentials and try again."
        case .authorization:
            return "You don't have permission to access this resource."
        case .validation:
            return "The provided data is invalid. Please check your input and try again."
        case .security:
            return "A security issue has been detected. Please contact support."
        case .network:
            return "Network connection failed. Please check your internet connection."
        case .database:
            return "A database error occurred. Please try again later."
        case .business:
            return "This operation could not be completed due to business rules."
        case .system:
            return "A system error occurred. Please try again later."
        case .external:
            return "An external service is currently unavailable. Please try again later."
        case .unknown:
            return "An unexpected error occurred. Please try again later."
        }
    }
    
    // MARK: - Error Response Generation
    
    /// Converts a structured error to a user-safe response
    public func generateErrorResponse(_ error: StructuredError) -> ErrorResponse {
        return ErrorResponse(structuredError: error)
    }
    
    /// Converts any error to a user-safe response
    public func generateErrorResponse(
        from error: Error,
        category: ErrorCategory = .unknown,
        context: ErrorContext = ErrorContext(),
        userMessage: String? = nil
    ) -> ErrorResponse {
        let structuredError = handle(
            error: error,
            category: category,
            context: context,
            userMessage: userMessage
        )
        return ErrorResponse(structuredError: structuredError)
    }
    
    // MARK: - Metrics and Reporting
    
    /// Gets error metrics for monitoring
    public func getMetrics() -> [String: Any] {
        return metricsQueue.sync {
            var metrics: [String: Any] = [:]
            
            for (key, errorMetrics) in self.errorMetrics {
                metrics[key] = [
                    "count": errorMetrics.count,
                    "lastOccurrence": errorMetrics.lastOccurrence,
                    "firstOccurrence": errorMetrics.firstOccurrence,
                    "averageFrequency": errorMetrics.averageFrequency
                ]
            }
            
            return metrics
        }
    }
    
    /// Gets metrics by category
    public func getMetricsByCategory() -> [ErrorCategory: Int] {
        return metricsQueue.sync {
            var categoryMetrics: [ErrorCategory: Int] = [:]
            
            for (key, errorMetrics) in self.errorMetrics {
                if let category = ErrorCategory(rawValue: key.components(separatedBy: ":").first ?? "") {
                    categoryMetrics[category, default: 0] += errorMetrics.count
                }
            }
            
            return categoryMetrics
        }
    }
    
    /// Clears old metrics data
    public func cleanupMetrics(olderThan timeInterval: TimeInterval = 86400) { // 24 hours default
        metricsQueue.async(flags: .barrier) {
            let cutoffDate = Date().addingTimeInterval(-timeInterval)
            
            self.errorMetrics = self.errorMetrics.compactMapValues { metrics in
                return metrics.lastOccurrence > cutoffDate ? metrics : nil
            }
        }
    }
    
    // MARK: - Configuration
    
    public func configure(
        loggingEnabled: Bool = true,
        metricsEnabled: Bool = true,
        alertsEnabled: Bool = true,
        maxErrorHistory: Int = 10000
    ) {
        queue.async(flags: .barrier) {
            self.isLoggingEnabled = loggingEnabled
            self.isMetricsEnabled = metricsEnabled
            self.shouldSendAlerts = alertsEnabled
            self.maxErrorHistory = maxErrorHistory
        }
    }
}

// MARK: - Convenience Extensions

public extension ErrorHandlingFramework {
    
    /// Quick method for authentication errors
    func handleAuthenticationError(
        code: String = "AUTH_FAILED",
        message: String,
        context: ErrorContext = ErrorContext(),
        underlyingError: Error? = nil
    ) -> StructuredError {
        return handle(
            category: .authentication,
            code: code,
            message: message,
            userMessage: "Authentication failed. Please check your credentials.",
            context: context,
            underlyingError: underlyingError,
            remediation: "Verify credentials and retry. Contact support if the issue persists."
        )
    }
    
    /// Quick method for validation errors
    func handleValidationError(
        code: String = "VALIDATION_FAILED",
        message: String,
        field: String? = nil,
        context: ErrorContext = ErrorContext()
    ) -> StructuredError {
        let userMessage = field != nil ? "Invalid \(field!)." : "Invalid input data."
        return handle(
            category: .validation,
            code: code,
            message: message,
            userMessage: userMessage,
            context: context,
            remediation: "Check your input data and try again."
        )
    }
    
    /// Quick method for security errors
    func handleSecurityError(
        code: String = "SECURITY_VIOLATION",
        message: String,
        context: ErrorContext = ErrorContext(),
        severity: ErrorPriority = .critical
    ) -> StructuredError {
        return handle(
            category: .security,
            code: code,
            message: message,
            userMessage: "A security issue has been detected.",
            context: context,
            remediation: "Contact security team immediately."
        )
    }
}

// MARK: - Error Recovery

/// Protocol for implementing error recovery strategies
public protocol ErrorRecoveryStrategy {
    func canRecover(from error: StructuredError) -> Bool
    func recover(from error: StructuredError) async throws -> Bool
}

/// Basic retry recovery strategy
public struct RetryRecoveryStrategy: ErrorRecoveryStrategy {
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    private let recoverableCategories: Set<ErrorCategory>
    
    public init(
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 1.0,
        recoverableCategories: Set<ErrorCategory> = [.network, .external, .system]
    ) {
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.recoverableCategories = recoverableCategories
    }
    
    public func canRecover(from error: StructuredError) -> Bool {
        return recoverableCategories.contains(error.category)
    }
    
    public func recover(from error: StructuredError) async throws -> Bool {
        for attempt in 1...maxRetries {
            try await Task.sleep(nanoseconds: UInt64(retryDelay * Double(attempt) * 1_000_000_000))
            
            // In a real implementation, you would retry the original operation here
            // For now, we'll simulate a recovery attempt
            let success = Bool.random()
            if success {
                return true
            }
        }
        return false
    }
}