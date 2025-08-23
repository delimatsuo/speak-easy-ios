import Foundation
import AVFoundation

class ErrorHandlingCoordinator {
    static let shared = ErrorHandlingCoordinator()
    
    private let networkMonitor = NetworkMonitor.shared
    private let logger = ErrorLogger.shared
    
    private init() {}
    
    enum ErrorCategory {
        case stt
        case network
        case api
        case audio
        case system
        case cache
        case security
    }
    
    func handleError(_ error: Error) -> ErrorRecoveryStrategy {
        logger.logError(error)
        
        switch error {
        case let sttError as SpeechRecognitionError:
            return handleSTTError(sttError)
            
        case let urlError as URLError:
            return handleNetworkError(urlError)
            
        case let translationError as TranslationError:
            return handleAPIError(translationError)
            
        case let ttsError as TTSError:
            return handleTTSError(ttsError)
            
        case let keychainError as KeychainError:
            return handleSecurityError(keychainError)
            
        default:
            return handleGenericError(error)
        }
    }
    
    private func handleSTTError(_ error: SpeechRecognitionError) -> ErrorRecoveryStrategy {
        switch error {
        case .audioEngineFailure:
            return .retry(
                after: 1.0,
                maxAttempts: 3,
                withFallback: .switchToTextInput
            )
            
        case .recognizerUnavailable:
            return .fallback(to: .manualTextInput)
            
        case .noSpeechDetected:
            return .showToast(
                "No speech detected. Please try again.",
                duration: 3.0
            )
            
        case .permissionDenied:
            return .requestPermission(
                type: .microphone,
                message: "Microphone access is required for speech recognition"
            )
            
        case .configurationFailed:
            return .retry(
                after: 0.5,
                maxAttempts: 2,
                withFallback: .showAlert(
                    title: "Audio Configuration Error",
                    message: "Please restart the app",
                    actions: [.restart, .cancel]
                )
            )
        }
    }
    
    private func handleNetworkError(_ error: URLError) -> ErrorRecoveryStrategy {
        switch error.code {
        case .notConnectedToInternet:
            return .switchToOfflineMode(
                withCache: true,
                showMessage: "No internet connection. Using offline mode."
            )
            
        case .timedOut:
            return .retry(
                after: 2.0,
                maxAttempts: 3,
                withBackoff: true
            )
            
        case .networkConnectionLost:
            return .queue(
                forLaterExecution: true,
                notifyUser: "Connection lost. Will retry when connected."
            )
            
        case .cannotConnectToHost:
            return .fallback(to: .alternativeAPI)
            
        case .badServerResponse:
            return .retry(
                after: 1.0,
                maxAttempts: 2,
                withBackoff: true
            )
            
        default:
            return .showAlert(
                title: "Network Error",
                message: "Please check your connection",
                actions: [.retry, .cancel]
            )
        }
    }
    
    private func handleAPIError(_ error: TranslationError) -> ErrorRecoveryStrategy {
        switch error {
        case .invalidAPIKey:
            return .requestAPIKey(
                message: "Please provide a valid API key to continue"
            )
            
        case .rateLimitExceeded(let retryAfter):
            return .queue(
                forLaterExecution: true,
                notifyUser: "Rate limit exceeded. Retrying in \(Int(retryAfter)) seconds."
            )
            
        case .textTooLong:
            return .splitAndRetry(
                chunkSize: 1000,
                message: "Text is too long. Splitting into smaller parts."
            )
            
        case .translationFailed(let reason):
            return .fallback(to: .alternativePrompt(reason: reason))
            
        case .networkTimeout:
            return .retry(
                after: 5.0,
                maxAttempts: 2,
                withBackoff: true
            )
            
        case .serverError(let statusCode):
            if statusCode >= 500 {
                return .retry(after: 10.0, maxAttempts: 3, withBackoff: true)
            } else {
                return .showAlert(
                    title: "Server Error",
                    message: "Error code: \(statusCode)",
                    actions: [.retry, .cancel]
                )
            }
            
        case .invalidLanguageCode(let code):
            return .fallback(to: .autoDetectLanguage(invalidCode: code))
            
        case .invalidResponse:
            return .retry(
                after: 1.0,
                maxAttempts: 2,
                withFallback: .showAlert(
                    title: "Invalid Response",
                    message: "Please try again",
                    actions: [.retry, .cancel]
                )
            )
        }
    }
    
    private func handleTTSError(_ error: TTSError) -> ErrorRecoveryStrategy {
        switch error {
        case .generationFailed(let reason):
            return .fallback(to: .simplifyText(reason: reason))
            
        case .unsupportedLanguage(let language):
            return .fallback(to: .defaultLanguage(requested: language))
            
        case .unsupportedVoice(let voice):
            return .fallback(to: .defaultVoice(requested: voice))
            
        case .invalidAudioData:
            return .retry(
                after: 1.0,
                maxAttempts: 2,
                withFallback: .showToast("Audio generation failed", duration: 3.0)
            )
            
        case .audioFormatConversionFailed:
            return .fallback(to: .alternativeAudioFormat)
            
        case .voiceNotAvailable:
            return .fallback(to: .availableVoice)
        }
    }
    
    private func handleSecurityError(_ error: KeychainError) -> ErrorRecoveryStrategy {
        switch error {
        case .storeFailed:
            return .requestPermission(
                type: .keychain,
                message: "Unable to securely store credentials"
            )
            
        case .retrieveFailed:
            return .requestAPIKey(
                message: "Unable to retrieve stored credentials. Please re-enter your API key."
            )
            
        case .deleteFailed:
            return .showAlert(
                title: "Security Error",
                message: "Unable to delete stored credentials",
                actions: [.retry, .cancel]
            )
            
        case .unexpectedPasswordData:
            return .fallback(to: .recreateKeychain)
        }
    }
    
    private func handleGenericError(_ error: Error) -> ErrorRecoveryStrategy {
        return .showAlert(
            title: "Unexpected Error",
            message: error.localizedDescription,
            actions: [.retry, .cancel]
        )
    }
    
    func shouldUseOfflineMode(for error: Error) -> Bool {
        switch error {
        case is URLError:
            return true
        case TranslationError.networkTimeout:
            return true
        case TranslationError.rateLimitExceeded:
            return networkMonitor.shouldUseOfflineMode()
        default:
            return false
        }
    }
    
    func getRecoveryOptions(for error: Error) -> [RecoveryOption] {
        let strategy = handleError(error)
        return strategy.availableOptions
    }
}

enum ErrorRecoveryStrategy {
    case retry(after: TimeInterval, maxAttempts: Int = 3, withBackoff: Bool = false, withFallback: ErrorRecoveryStrategy? = nil)
    case fallback(to: FallbackOption)
    case switchToOfflineMode(withCache: Bool, showMessage: String)
    case queue(forLaterExecution: Bool, notifyUser: String)
    case showAlert(title: String, message: String, actions: [AlertAction])
    case showToast(String, duration: TimeInterval)
    case requestPermission(type: PermissionType, message: String)
    case requestAPIKey(message: String)
    case splitAndRetry(chunkSize: Int, message: String)
    
    var availableOptions: [RecoveryOption] {
        switch self {
        case .retry:
            return [.retry, .cancel]
        case .fallback:
            return [.useFallback, .retry, .cancel]
        case .switchToOfflineMode:
            return [.useOfflineMode, .retry, .cancel]
        case .queue:
            return [.queueForLater, .cancel]
        case .showAlert(_, _, let actions):
            return actions.map { RecoveryOption(rawValue: $0.rawValue) ?? .cancel }
        case .showToast:
            return [.dismiss]
        case .requestPermission:
            return [.grantPermission, .cancel]
        case .requestAPIKey:
            return [.provideAPIKey, .cancel]
        case .splitAndRetry:
            return [.splitAndRetry, .cancel]
        }
    }
    
    enum FallbackOption {
        case manualTextInput
        case cachedTranslation
        case alternativeAPI
        case alternativePrompt(reason: String)
        case autoDetectLanguage(invalidCode: String)
        case simplifyText(reason: String)
        case defaultLanguage(requested: String)
        case defaultVoice(requested: String)
        case alternativeAudioFormat
        case availableVoice
        case recreateKeychain
    }
}

enum RecoveryOption: String, CaseIterable {
    case retry = "Retry"
    case cancel = "Cancel"
    case useFallback = "Use Alternative"
    case useOfflineMode = "Go Offline"
    case queueForLater = "Try Later"
    case dismiss = "Dismiss"
    case grantPermission = "Grant Permission"
    case provideAPIKey = "Provide API Key"
    case splitAndRetry = "Split Text"
    case restart = "Restart App"
}

enum PermissionType {
    case microphone
    case keychain
    case notifications
}

enum AlertAction: String {
    case retry = "Retry"
    case cancel = "Cancel"
    case restart = "Restart"
    case settings = "Settings"
}

class ErrorLogger {
    static let shared = ErrorLogger()
    
    private let logQueue = DispatchQueue(label: "error.logger.queue")
    private let maxLogEntries = 1000
    private var logEntries: [LogEntry] = []
    
    private init() {}
    
    func logError(_ error: Error, context: String? = nil) {
        logQueue.async {
            let entry = LogEntry(
                error: error,
                context: context,
                timestamp: Date(),
                stackTrace: Thread.callStackSymbols
            )
            
            self.logEntries.append(entry)
            
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
            }
            
            self.writeToFile(entry)
        }
    }
    
    func getRecentErrors(limit: Int = 50) -> [LogEntry] {
        return logQueue.sync {
            return Array(logEntries.suffix(limit))
        }
    }
    
    func clearLogs() {
        logQueue.async {
            self.logEntries.removeAll()
            self.clearLogFile()
        }
    }
    
    private func writeToFile(_ entry: LogEntry) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logFileURL = documentsPath.appendingPathComponent("error_logs.txt")
        let logString = formatLogEntry(entry)
        
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(logString.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            }
        } else {
            try? logString.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }
    
    private func formatLogEntry(_ entry: LogEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var logString = """
        [\(formatter.string(from: entry.timestamp))] ERROR: \(entry.error.localizedDescription)
        Type: \(String(describing: type(of: entry.error)))
        """
        
        if let context = entry.context {
            logString += "\nContext: \(context)"
        }
        
        logString += "\nStack Trace:\n\(entry.stackTrace.joined(separator: "\n"))\n\n"
        
        return logString
    }
    
    private func clearLogFile() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logFileURL = documentsPath.appendingPathComponent("error_logs.txt")
        try? FileManager.default.removeItem(at: logFileURL)
    }
}

struct LogEntry {
    let error: Error
    let context: String?
    let timestamp: Date
    let stackTrace: [String]
}