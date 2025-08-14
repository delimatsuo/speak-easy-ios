import Foundation
import os.log

final class SecurityLogger {
    static let shared = SecurityLogger()
    
    private let logger = OSLog(subsystem: "com.mervyntalks.security", category: "Security")
    private let queue = DispatchQueue(label: "com.mervyntalks.security.logger")
    
    private var securityEvents: [(timestamp: Date, event: String)] = []
    private let maxEvents = 1000
    
    private init() {}
    
    func logSecurityEvent(_ event: SecurityEvent, details: [String: Any] = [:]) {
        queue.async {
            let timestamp = Date()
            let eventString = self.formatEvent(event, details: details)
            
            // Log to system
            os_log("%{public}@", log: self.logger, type: event.logType, eventString)
            
            // Store in memory
            self.securityEvents.append((timestamp, eventString))
            if self.securityEvents.count > self.maxEvents {
                self.securityEvents.removeFirst()
            }
            
            // Write to file if critical
            if event.isCritical {
                self.writeToFile(event: eventString)
            }
        }
    }
    
    private func formatEvent(_ event: SecurityEvent, details: [String: Any]) -> String {
        var components = ["[SECURITY]", "[\(event.rawValue)]"]
        
        if !details.isEmpty {
            let detailsString = details.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            components.append("{\(detailsString)}")
        }
        
        return components.joined(separator: " ")
    }
    
    private func writeToFile(event: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logFile = documentsPath.appendingPathComponent("security.log")
        let logEntry = "\(Date()): \(event)\n"
        
        do {
            if !FileManager.default.fileExists(atPath: logFile.path) {
                try "Security Log File\n".write(to: logFile, atomically: true, encoding: .utf8)
            }
            
            let handle = try FileHandle(forWritingTo: logFile)
            handle.seekToEndOfFile()
            handle.write(logEntry.data(using: .utf8) ?? Data())
            handle.closeFile()
        } catch {
            os_log("Failed to write security log: %{public}@", log: logger, type: .error, error.localizedDescription)
        }
    }
    
    func getRecentEvents(count: Int = 100) -> [(timestamp: Date, event: String)] {
        return queue.sync {
            Array(securityEvents.suffix(count))
        }
    }
}

enum SecurityEvent: String {
    // Certificate pinning events
    case certificatePinningSuccess = "CERT_PIN_SUCCESS"
    case certificatePinningFailure = "CERT_PIN_FAILURE"
    case certificateChainInvalid = "CERT_CHAIN_INVALID"
    case untrustedHost = "UNTRUSTED_HOST"
    
    // Authentication events
    case authenticationSuccess = "AUTH_SUCCESS"
    case authenticationFailure = "AUTH_FAILURE"
    case invalidToken = "INVALID_TOKEN"
    case tokenExpired = "TOKEN_EXPIRED"
    
    // API security events
    case apiKeyRotated = "API_KEY_ROTATED"
    case apiKeyRotationFailed = "API_KEY_ROTATION_FAILED"
    case rateLimitExceeded = "RATE_LIMIT_EXCEEDED"
    
    // Suspicious activity
    case suspiciousRequest = "SUSPICIOUS_REQUEST"
    case possibleAttackAttempt = "ATTACK_ATTEMPT"
    
    var logType: OSLogType {
        switch self {
        case .certificatePinningFailure,
             .certificateChainInvalid,
             .untrustedHost,
             .authenticationFailure,
             .invalidToken,
             .apiKeyRotationFailed,
             .possibleAttackAttempt:
            return .error
        case .rateLimitExceeded,
             .tokenExpired,
             .suspiciousRequest:
            return .fault
        default:
            return .info
        }
    }
    
    var isCritical: Bool {
        switch self {
        case .certificatePinningFailure,
             .certificateChainInvalid,
             .untrustedHost,
             .authenticationFailure,
             .possibleAttackAttempt:
            return true
        default:
            return false
        }
    }
}
