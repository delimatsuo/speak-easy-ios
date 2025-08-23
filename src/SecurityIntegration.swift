import Foundation
import UIKit

/// Integration layer that combines all security components into a unified system
public class SecurityIntegration {
    
    // MARK: - Singleton
    
    public static let shared = SecurityIntegration()
    private init() {
        setupSecurityFramework()
    }
    
    // MARK: - Components
    
    private let rateLimiter = EnhancedRateLimiter()
    private let securityMonitor = SecurityMonitor.shared
    private let errorHandler = ErrorHandlingFramework.shared
    private let nonceManager = NonceManager()
    
    // MARK: - Configuration
    
    private var isSecurityEnabled = true
    private var logSecurityEvents = true
    private var alertsEnabled = true
    
    // MARK: - Setup
    
    private func setupSecurityFramework() {
        configureRateLimits()
        configureErrorHandlers()
        configureSecurityMonitoring()
        setupSecurityAlerts()
    }
    
    private func configureRateLimits() {
        // Configure rate limits for different endpoints
        rateLimiter.applyPreset(.moderate, for: "translation")
        rateLimiter.applyPreset(.strict, for: "authentication")
        rateLimiter.applyPreset(.api, for: "general")
        rateLimiter.applyPreset(.burst, for: "realtime")
    }
    
    private func configureErrorHandlers() {
        // Add security-specific error handlers
        errorHandler.addHandler(for: .security) { [weak self] error in
            self?.handleSecurityError(error)
        }
        
        errorHandler.addHandler(for: .authentication) { [weak self] error in
            self?.handleAuthenticationError(error)
        }
        
        errorHandler.addHandler(for: .validation) { [weak self] error in
            self?.handleValidationError(error)
        }
    }
    
    private func configureSecurityMonitoring() {
        securityMonitor.configure(
            maxIncidentHistory: 50000,
            failedLoginThreshold: 3,
            timeWindowMinutes: 10,
            suspiciousIPThreshold: 15,
            riskScoreThreshold: 0.6,
            enableRealTimeAnalysis: true
        )
    }
    
    private func setupSecurityAlerts() {
        securityMonitor.addAlertHandler { [weak self] incident in
            self?.handleSecurityAlert(incident)
        }
    }
    
    // MARK: - Authentication Security
    
    /// Securely handles user authentication with comprehensive security checks
    public func authenticateUser(
        credentials: UserCredentials,
        context: SecurityContext
    ) async -> AuthenticationResult {
        
        // Check rate limits first
        let rateLimitResult = rateLimiter.checkRateLimit(
            for: "authentication",
            userID: credentials.username
        )
        
        guard rateLimitResult.allowed else {
            let error = errorHandler.handle(
                category: .authentication,
                code: "AUTH_RATE_LIMITED",
                message: "Authentication rate limit exceeded",
                userMessage: "Too many login attempts. Please try again later.",
                context: ErrorHandlingFramework.ErrorContext(
                    userID: credentials.username,
                    ipAddress: context.ipAddress,
                    userAgent: context.userAgent
                )
            )
            
            securityMonitor.recordIncident(
                event: .rateLimitViolation,
                userID: credentials.username,
                ipAddress: context.ipAddress,
                userAgent: context.userAgent,
                endpoint: "auth/login"
            )
            
            return .rateLimited(retryAfter: rateLimitResult.retryAfter ?? 60)
        }
        
        // Validate input
        do {
            try InputValidator.validateTextInput(credentials.username, options: ValidationOptions(
                maxLength: 255,
                checkSQLInjection: true,
                checkXSS: true
            ))
            
            try InputValidator.validateTextInput(credentials.password, options: ValidationOptions(
                maxLength: 1000,
                checkSQLInjection: true,
                checkXSS: true
            ))
        } catch {
            let validationError = errorHandler.handle(
                error: error,
                category: .validation,
                context: ErrorHandlingFramework.ErrorContext(
                    userID: credentials.username,
                    ipAddress: context.ipAddress,
                    userAgent: context.userAgent
                )
            )
            
            return .failed(error: validationError)
        }
        
        // Perform authentication (placeholder - implement your actual auth logic)
        let authResult = await performAuthentication(credentials)
        
        if authResult.success {
            // Successful authentication
            securityMonitor.recordIncident(
                event: .unauthorizedAccess, // This would be a successful login event in real implementation
                userID: credentials.username,
                ipAddress: context.ipAddress,
                userAgent: context.userAgent,
                endpoint: "auth/login",
                details: ["result": "success"]
            )
            
            rateLimiter.incrementCount(for: "authentication", userID: credentials.username)
            return .success(token: authResult.token!, user: authResult.user!)
            
        } else {
            // Failed authentication
            securityMonitor.recordAuthenticationFailure(
                userID: credentials.username,
                ipAddress: context.ipAddress,
                userAgent: context.userAgent
            )
            
            let authError = errorHandler.handleAuthenticationError(
                message: "Invalid credentials provided",
                context: ErrorHandlingFramework.ErrorContext(
                    userID: credentials.username,
                    ipAddress: context.ipAddress,
                    userAgent: context.userAgent
                )
            )
            
            return .failed(error: authError)
        }
    }
    
    // MARK: - Request Security
    
    /// Validates and secures incoming requests
    public func validateRequest(
        request: APIRequest,
        context: SecurityContext
    ) -> RequestValidationResult {
        
        // Input validation
        let validationOptions = ValidationOptions(
            maxLength: 10000,
            checkSQLInjection: true,
            checkXSS: true,
            checkPathTraversal: true
        )
        
        do {
            // Validate all string inputs
            for (key, value) in request.parameters {
                if let stringValue = value as? String {
                    try InputValidator.validateTextInput(stringValue, options: validationOptions)
                }
            }
            
            // Validate path
            try InputValidator.validatePath(request.path)
            
            // Validate user agent
            if let userAgent = context.userAgent {
                try InputValidator.validateTextInput(userAgent, options: validationOptions)
            }
            
        } catch let error as InputValidator.ValidationError {
            // Log security incident based on validation error type
            var securityEvent: SecurityMonitor.SecurityEvent = .unusualRequestPattern
            
            switch error {
            case .sqlInjectionDetected:
                securityEvent = .sqlInjectionAttempt
            case .xssDetected:
                securityEvent = .xssAttempt
            case .pathTraversalDetected:
                securityEvent = .pathTraversalAttempt
            default:
                securityEvent = .unusualRequestPattern
            }
            
            securityMonitor.recordInjectionAttempt(
                type: securityEvent,
                input: error.localizedDescription,
                endpoint: request.path,
                ipAddress: context.ipAddress
            )
            
            let structuredError = errorHandler.handle(
                error: error,
                category: .validation,
                context: ErrorHandlingFramework.ErrorContext(
                    userID: context.userID,
                    ipAddress: context.ipAddress,
                    userAgent: context.userAgent,
                    endpoint: request.path
                )
            )
            
            return .invalid(error: structuredError)
        } catch {
            let structuredError = errorHandler.handle(
                error: error,
                category: .validation,
                context: ErrorHandlingFramework.ErrorContext(
                    userID: context.userID,
                    ipAddress: context.ipAddress,
                    userAgent: context.userAgent,
                    endpoint: request.path
                )
            )
            
            return .invalid(error: structuredError)
        }
        
        // Rate limiting
        let rateLimitResult = rateLimiter.checkMultipleLimits(
            userID: context.userID ?? "anonymous",
            endpoint: request.path
        )
        
        if !rateLimitResult.allowed {
            securityMonitor.recordRateLimitViolation(
                endpoint: request.path,
                userID: context.userID,
                ipAddress: context.ipAddress
            )
            
            let rateLimitError = errorHandler.handle(
                category: .security,
                code: "RATE_LIMIT_EXCEEDED",
                message: "Rate limit exceeded for endpoint",
                userMessage: "Too many requests. Please slow down.",
                context: ErrorHandlingFramework.ErrorContext(
                    userID: context.userID,
                    ipAddress: context.ipAddress,
                    userAgent: context.userAgent,
                    endpoint: request.path
                )
            )
            
            return .rateLimited(error: rateLimitError, retryAfter: rateLimitResult.retryAfter ?? 60)
        }
        
        return .valid
    }
    
    // MARK: - Data Encryption
    
    /// Securely encrypts sensitive data
    public func encryptSensitiveData(_ data: Data, key: Data) throws -> EncryptedData {
        do {
            let encryptedData = try SecureEncryption.encrypt(data: data, key: key)
            
            // Store nonce for replay protection
            try nonceManager.validateAndStore(nonce: encryptedData.nonce)
            
            return encryptedData
        } catch {
            let securityError = errorHandler.handle(
                error: error,
                category: .security,
                userMessage: "Failed to encrypt data"
            )
            
            throw securityError
        }
    }
    
    /// Securely decrypts sensitive data
    public func decryptSensitiveData(_ encryptedData: EncryptedData, key: Data) throws -> Data {
        do {
            // Validate nonce to prevent replay attacks
            try nonceManager.validateAndStore(nonce: encryptedData.nonce)
            
            let decryptedData = try SecureEncryption.decrypt(encryptedData: encryptedData, key: key)
            return decryptedData
        } catch {
            let securityError = errorHandler.handle(
                error: error,
                category: .security,
                userMessage: "Failed to decrypt data"
            )
            
            throw securityError
        }
    }
    
    // MARK: - Security Event Handlers
    
    private func handleSecurityError(_ error: ErrorHandlingFramework.StructuredError) {
        // Log to security monitor
        securityMonitor.recordIncident(
            event: .suspiciousUserAgent, // Adjust based on error specifics
            userID: error.context.userID,
            ipAddress: error.context.ipAddress,
            userAgent: error.context.userAgent,
            endpoint: error.context.endpoint,
            details: [
                "error_code": error.code,
                "error_message": error.message
            ]
        )
    }
    
    private func handleAuthenticationError(_ error: ErrorHandlingFramework.StructuredError) {
        // Record authentication failure
        securityMonitor.recordAuthenticationFailure(
            userID: error.context.userID,
            ipAddress: error.context.ipAddress,
            userAgent: error.context.userAgent
        )
    }
    
    private func handleValidationError(_ error: ErrorHandlingFramework.StructuredError) {
        // Record suspicious input patterns
        securityMonitor.recordIncident(
            event: .unusualRequestPattern,
            userID: error.context.userID,
            ipAddress: error.context.ipAddress,
            userAgent: error.context.userAgent,
            endpoint: error.context.endpoint,
            details: [
                "validation_error": error.message
            ]
        )
    }
    
    private func handleSecurityAlert(_ incident: SecurityMonitor.SecurityIncident) {
        if alertsEnabled {
            // In a real implementation, this would send alerts to your monitoring system
            print("🚨 Security Alert: \(incident.event.rawValue) - Risk Score: \(incident.riskScore)")
            
            // For critical incidents, you might want to:
            if incident.severity == .critical {
                // - Send push notifications to security team
                // - Create tickets in incident management system
                // - Trigger automated response actions
                // - Block suspicious IPs temporarily
            }
        }
    }
    
    // MARK: - Security Metrics
    
    /// Gets comprehensive security metrics
    public func getSecurityMetrics() -> ComprehensiveSecurityMetrics {
        let securityMetrics = securityMonitor.getSecurityMetrics()
        let rateLimitStats = rateLimiter.getStatistics()
        let errorMetrics = errorHandler.getMetricsByCategory()
        
        return ComprehensiveSecurityMetrics(
            securityIncidents: securityMetrics,
            rateLimitingStats: rateLimitStats,
            errorStats: errorMetrics,
            timestamp: Date()
        )
    }
    
    /// Generates security dashboard data
    public func getSecurityDashboard() -> SecurityDashboard {
        let metrics = getSecurityMetrics()
        
        return SecurityDashboard(
            overallRiskScore: calculateOverallRiskScore(metrics),
            criticalAlerts: metrics.securityIncidents.criticalIncidentsLast24Hours,
            activeThreats: metrics.securityIncidents.highRiskIncidents,
            blockedAttacks: metrics.rateLimitingStats.totalViolations,
            topThreats: Array(metrics.securityIncidents.incidentsByType.sorted { $0.value > $1.value }.prefix(5)),
            systemHealth: calculateSystemHealth(metrics)
        )
    }
    
    private func calculateOverallRiskScore(_ metrics: ComprehensiveSecurityMetrics) -> Double {
        var riskScore = 0.0
        
        // Factor in recent incidents
        if metrics.securityIncidents.incidentsLast24Hours > 0 {
            riskScore += Double(metrics.securityIncidents.criticalIncidentsLast24Hours) * 0.4
            riskScore += Double(metrics.securityIncidents.highRiskIncidentsLast24Hours) * 0.2
            riskScore += metrics.securityIncidents.averageRiskScore * 0.3
        }
        
        // Factor in rate limiting violations
        if metrics.rateLimitingStats.activeViolations > 0 {
            riskScore += min(0.1, Double(metrics.rateLimitingStats.activeViolations) / 100.0)
        }
        
        return min(1.0, riskScore)
    }
    
    private func calculateSystemHealth(_ metrics: ComprehensiveSecurityMetrics) -> String {
        let riskScore = calculateOverallRiskScore(metrics)
        
        switch riskScore {
        case 0.0..<0.3:
            return "Healthy"
        case 0.3..<0.6:
            return "Warning"
        case 0.6..<0.8:
            return "Critical"
        default:
            return "Emergency"
        }
    }
    
    // MARK: - Configuration
    
    public func configure(
        securityEnabled: Bool = true,
        logSecurityEvents: Bool = true,
        alertsEnabled: Bool = true
    ) {
        self.isSecurityEnabled = securityEnabled
        self.logSecurityEvents = logSecurityEvents
        self.alertsEnabled = alertsEnabled
    }
}

// MARK: - Supporting Types

public struct UserCredentials {
    public let username: String
    public let password: String
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct SecurityContext {
    public let userID: String?
    public let sessionID: String?
    public let ipAddress: String?
    public let userAgent: String?
    public let timestamp: Date
    
    public init(
        userID: String? = nil,
        sessionID: String? = nil,
        ipAddress: String? = nil,
        userAgent: String? = nil,
        timestamp: Date = Date()
    ) {
        self.userID = userID
        self.sessionID = sessionID
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.timestamp = timestamp
    }
}

public struct APIRequest {
    public let path: String
    public let method: String
    public let parameters: [String: Any]
    public let headers: [String: String]
    
    public init(
        path: String,
        method: String,
        parameters: [String: Any] = [:],
        headers: [String: String] = [:]
    ) {
        self.path = path
        self.method = method
        self.parameters = parameters
        self.headers = headers
    }
}

public enum AuthenticationResult {
    case success(token: String, user: User)
    case failed(error: ErrorHandlingFramework.StructuredError)
    case rateLimited(retryAfter: TimeInterval)
}

public enum RequestValidationResult {
    case valid
    case invalid(error: ErrorHandlingFramework.StructuredError)
    case rateLimited(error: ErrorHandlingFramework.StructuredError, retryAfter: TimeInterval)
}

public struct User {
    public let id: String
    public let username: String
    public let email: String
    
    public init(id: String, username: String, email: String) {
        self.id = id
        self.username = username
        self.email = email
    }
}

public struct AuthResult {
    public let success: Bool
    public let token: String?
    public let user: User?
    
    public init(success: Bool, token: String? = nil, user: User? = nil) {
        self.success = success
        self.token = token
        self.user = user
    }
}

public struct ComprehensiveSecurityMetrics {
    public let securityIncidents: SecurityMetrics
    public let rateLimitingStats: RateLimitStatistics
    public let errorStats: [ErrorHandlingFramework.ErrorCategory: Int]
    public let timestamp: Date
    
    public init(
        securityIncidents: SecurityMetrics,
        rateLimitingStats: RateLimitStatistics,
        errorStats: [ErrorHandlingFramework.ErrorCategory: Int],
        timestamp: Date
    ) {
        self.securityIncidents = securityIncidents
        self.rateLimitingStats = rateLimitingStats
        self.errorStats = errorStats
        self.timestamp = timestamp
    }
}

public struct SecurityDashboard {
    public let overallRiskScore: Double
    public let criticalAlerts: Int
    public let activeThreats: Int
    public let blockedAttacks: Int
    public let topThreats: [(SecurityMonitor.SecurityEvent, Int)]
    public let systemHealth: String
    
    public init(
        overallRiskScore: Double,
        criticalAlerts: Int,
        activeThreats: Int,
        blockedAttacks: Int,
        topThreats: [(SecurityMonitor.SecurityEvent, Int)],
        systemHealth: String
    ) {
        self.overallRiskScore = overallRiskScore
        self.criticalAlerts = criticalAlerts
        self.activeThreats = activeThreats
        self.blockedAttacks = blockedAttacks
        self.topThreats = topThreats
        self.systemHealth = systemHealth
    }
}

// MARK: - Convenience Extensions

public extension SecurityIntegration {
    
    /// Quick validation for user input
    func validateUserInput(_ input: String, field: String) -> Bool {
        do {
            try InputValidator.validateTextInput(input, options: ValidationOptions(
                maxLength: 1000,
                checkSQLInjection: true,
                checkXSS: true
            ))
            return true
        } catch {
            errorHandler.handleValidationError(
                message: "Invalid input in field: \(field)",
                field: field
            )
            return false
        }
    }
    
    /// Quick authentication check
    func isRequestAllowed(userID: String, endpoint: String) -> Bool {
        let result = rateLimiter.checkRateLimit(for: endpoint, userID: userID)
        return result.allowed
    }
    
    /// Quick security incident recording
    func reportSuspiciousActivity(
        userID: String?,
        ipAddress: String?,
        description: String
    ) {
        securityMonitor.recordIncident(
            event: .unusualRequestPattern,
            userID: userID,
            ipAddress: ipAddress,
            details: ["description": description]
        )
    }
}

// MARK: - Authentication Implementation Placeholder

private func performAuthentication(_ credentials: UserCredentials) async -> AuthResult {
    // Placeholder implementation - replace with your actual authentication logic
    await Task.sleep(100_000_000) // Simulate network delay
    
    // Simple validation for demo purposes
    if credentials.username == "admin" && credentials.password == "password123" {
        let user = User(id: "1", username: credentials.username, email: "admin@example.com")
        return AuthResult(success: true, token: "jwt-token-here", user: user)
    }
    
    return AuthResult(success: false)
}