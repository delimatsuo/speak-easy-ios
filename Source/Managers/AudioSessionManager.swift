import Foundation
import AVFoundation

class AudioSessionManager {
    static let shared = AudioSessionManager()
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var isConfiguredForRecording = false
    private var isConfiguredForPlayback = false
    
    private init() {
        setupNotifications()
    }
    
    deinit {
        removeNotifications()
    }
    
    func configureForRecording() throws {
        guard !isConfiguredForRecording else { return }
        
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        isConfiguredForRecording = true
        isConfiguredForPlayback = false
        
        print("Audio session configured for recording")
    }
    
    func configureForPlayback() throws {
        guard !isConfiguredForPlayback else { return }
        
        try audioSession.setCategory(
            .playback,
            mode: .default,
            options: [.defaultToSpeaker, .duckOthers, .allowBluetooth, .allowBluetoothA2DP]
        )
        
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        isConfiguredForPlayback = true
        isConfiguredForRecording = false
        
        print("Audio session configured for playback")
    }
    
    func configureForSilent() throws {
        try audioSession.setCategory(.ambient, mode: .default)
        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        
        isConfiguredForRecording = false
        isConfiguredForPlayback = false
        
        print("Audio session configured for silent mode")
    }
    
    func requestRecordPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func getRecordPermissionStatus() -> AVAudioSession.RecordPermission {
        return audioSession.recordPermission
    }
    
    func getCurrentRoute() -> AVAudioSessionRouteDescription {
        return audioSession.currentRoute
    }
    
    func getAvailableInputs() -> [AVAudioSessionPortDescription]? {
        return audioSession.availableInputs
    }
    
    func setPreferredInput(_ input: AVAudioSessionPortDescription?) throws {
        try audioSession.setPreferredInput(input)
    }
    
    func setPreferredSampleRate(_ sampleRate: Double) throws {
        try audioSession.setPreferredSampleRate(sampleRate)
    }
    
    func setPreferredIOBufferDuration(_ duration: TimeInterval) throws {
        try audioSession.setPreferredIOBufferDuration(duration)
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesLost),
            name: AVAudioSession.mediaServicesWereLostNotification,
            object: nil
        )
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            handleInterruptionBegan()
            
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            handleInterruptionEnded(options: options)
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable:
            handleNewDeviceAvailable()
            
        case .oldDeviceUnavailable:
            handleOldDeviceUnavailable()
            
        case .categoryChange:
            handleCategoryChange()
            
        case .override:
            handleRouteOverride()
            
        case .wakeFromSleep:
            handleWakeFromSleep()
            
        case .noSuitableRouteForCategory:
            handleNoSuitableRoute()
            
        case .routeConfigurationChange:
            handleRouteConfigurationChange()
            
        @unknown default:
            break
        }
        
        logRouteChange(reason: reason)
    }
    
    @objc private func handleMediaServicesReset(_ notification: Notification) {
        print("Media services were reset - reconfiguring audio session")
        reconfigureAfterReset()
    }
    
    @objc private func handleMediaServicesLost(_ notification: Notification) {
        print("Media services were lost")
        isConfiguredForRecording = false
        isConfiguredForPlayback = false
    }
    
    private func handleInterruptionBegan() {
        print("Audio interruption began")
        NotificationCenter.default.post(name: .audioInterruptionBegan, object: nil)
    }
    
    private func handleInterruptionEnded(options: AVAudioSession.InterruptionOptions) {
        print("Audio interruption ended")
        
        if options.contains(.shouldResume) {
            do {
                try audioSession.setActive(true)
                NotificationCenter.default.post(name: .audioInterruptionEndedShouldResume, object: nil)
            } catch {
                print("Failed to reactivate audio session: \(error)")
                NotificationCenter.default.post(name: .audioInterruptionEndedWithError, object: error)
            }
        } else {
            NotificationCenter.default.post(name: .audioInterruptionEnded, object: nil)
        }
    }
    
    private func handleNewDeviceAvailable() {
        print("New audio device available")
        let currentRoute = audioSession.currentRoute
        logCurrentRoute(currentRoute)
        
        NotificationCenter.default.post(
            name: .audioDeviceChanged,
            object: nil,
            userInfo: ["route": currentRoute]
        )
    }
    
    private func handleOldDeviceUnavailable() {
        print("Audio device became unavailable")
        
        if isConfiguredForRecording {
            do {
                try configureForRecording()
            } catch {
                print("Failed to reconfigure for recording: \(error)")
            }
        } else if isConfiguredForPlayback {
            do {
                try configureForPlayback()
            } catch {
                print("Failed to reconfigure for playback: \(error)")
            }
        }
    }
    
    private func handleCategoryChange() {
        print("Audio category changed")
    }
    
    private func handleRouteOverride() {
        print("Audio route override")
    }
    
    private func handleWakeFromSleep() {
        print("Audio session wake from sleep")
        reconfigureAfterReset()
    }
    
    private func handleNoSuitableRoute() {
        print("No suitable audio route for category")
        NotificationCenter.default.post(name: .audioNoSuitableRoute, object: nil)
    }
    
    private func handleRouteConfigurationChange() {
        print("Audio route configuration changed")
    }
    
    private func reconfigureAfterReset() {
        if isConfiguredForRecording {
            do {
                try configureForRecording()
            } catch {
                print("Failed to reconfigure for recording after reset: \(error)")
            }
        } else if isConfiguredForPlayback {
            do {
                try configureForPlayback()
            } catch {
                print("Failed to reconfigure for playback after reset: \(error)")
            }
        }
    }
    
    private func logRouteChange(reason: AVAudioSession.RouteChangeReason) {
        print("Audio route changed - reason: \(reason.description)")
    }
    
    private func logCurrentRoute(_ route: AVAudioSessionRouteDescription) {
        print("Current audio route:")
        print("  Inputs: \(route.inputs.map { $0.portName }.joined(separator: ", "))")
        print("  Outputs: \(route.outputs.map { $0.portName }.joined(separator: ", "))")
    }
    
    func getAudioSessionInfo() -> AudioSessionInfo {
        return AudioSessionInfo(
            category: audioSession.category,
            mode: audioSession.mode,
            options: audioSession.categoryOptions,
            isActive: audioSession.isOtherAudioPlaying,
            sampleRate: audioSession.sampleRate,
            ioBufferDuration: audioSession.ioBufferDuration,
            currentRoute: audioSession.currentRoute,
            availableInputs: audioSession.availableInputs ?? [],
            recordPermission: audioSession.recordPermission
        )
    }
}

struct AudioSessionInfo {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
    let isActive: Bool
    let sampleRate: Double
    let ioBufferDuration: TimeInterval
    let currentRoute: AVAudioSessionRouteDescription
    let availableInputs: [AVAudioSessionPortDescription]
    let recordPermission: AVAudioSession.RecordPermission
}

extension AVAudioSession.RouteChangeReason {
    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .newDeviceAvailable:
            return "New Device Available"
        case .oldDeviceUnavailable:
            return "Old Device Unavailable"
        case .categoryChange:
            return "Category Change"
        case .override:
            return "Override"
        case .wakeFromSleep:
            return "Wake From Sleep"
        case .noSuitableRouteForCategory:
            return "No Suitable Route"
        case .routeConfigurationChange:
            return "Route Configuration Change"
        @unknown default:
            return "Unknown (\(rawValue))"
        }
    }
}

extension Notification.Name {
    static let audioInterruptionBegan = Notification.Name("audioInterruptionBegan")
    static let audioInterruptionEnded = Notification.Name("audioInterruptionEnded")
    static let audioInterruptionEndedShouldResume = Notification.Name("audioInterruptionEndedShouldResume")
    static let audioInterruptionEndedWithError = Notification.Name("audioInterruptionEndedWithError")
    static let audioDeviceChanged = Notification.Name("audioDeviceChanged")
    static let audioNoSuitableRoute = Notification.Name("audioNoSuitableRoute")
}