import UIKit
import SwiftUI

enum DeviceClass {
    case iPhoneSE        // iPhone SE (2nd/3rd gen), Mini form factor
    case iPhoneStandard  // iPhone 12/13/14/15 (6.1")
    case iPhonePlus      // iPhone 12/13/14/15 Plus (6.7")
    case iPhonePro       // iPhone 12/13/14/15 Pro (6.1")
    case iPhoneProMax    // iPhone 12/13/14/15 Pro Max (6.7")
    case unknown
    
    var screenSize: CGSize {
        switch self {
        case .iPhoneSE:
            return CGSize(width: 375, height: 667)
        case .iPhoneStandard, .iPhonePro:
            return CGSize(width: 390, height: 844)
        case .iPhonePlus, .iPhoneProMax:
            return CGSize(width: 428, height: 926)
        case .unknown:
            return UIScreen.main.bounds.size
        }
    }
    
    var hasNotch: Bool {
        switch self {
        case .iPhoneSE:
            return false
        default:
            return true
        }
    }
    
    var hasDynamicIsland: Bool {
        switch self {
        case .iPhonePro, .iPhoneProMax:
            return true // iPhone 14 Pro and later
        default:
            return false
        }
    }
    
    var recommendedAnimationDuration: TimeInterval {
        switch self {
        case .iPhoneSE:
            return 0.2 // Slightly faster for older hardware
        default:
            return 0.3
        }
    }
    
    var maxConcurrentOperations: Int {
        switch self {
        case .iPhoneSE:
            return 2
        case .iPhoneStandard, .iPhonePlus:
            return 3
        case .iPhonePro, .iPhoneProMax:
            return 4
        case .unknown:
            return 2
        }
    }
    
    var shouldReduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled || self == .iPhoneSE
    }
}

class DeviceOptimization {
    static let shared = DeviceOptimization()
    
    private(set) var deviceClass: DeviceClass = .unknown
    private(set) var isLowPowerModeEnabled = false
    
    private init() {
        detectDeviceClass()
        setupLowPowerModeObserver()
    }
    
    // MARK: - Device Detection
    
    private func detectDeviceClass() {
        let screenSize = UIScreen.main.bounds.size
        let scale = UIScreen.main.scale
        
        // Detect based on screen size and other characteristics
        if screenSize.width == 375 && screenSize.height == 667 {
            deviceClass = .iPhoneSE
        } else if screenSize.width == 390 && screenSize.height == 844 {
            // Check if Pro model based on available features
            if #available(iOS 16.1, *), hasProMotion() {
                deviceClass = .iPhonePro
            } else {
                deviceClass = .iPhoneStandard
            }
        } else if screenSize.width == 428 && screenSize.height == 926 {
            // Check if Pro Max based on available features
            if #available(iOS 16.1, *), hasProMotion() {
                deviceClass = .iPhoneProMax
            } else {
                deviceClass = .iPhonePlus
            }
        } else {
            deviceClass = .unknown
        }
    }
    
    @available(iOS 16.1, *)
    private func hasProMotion() -> Bool {
        return UIScreen.main.maximumFramesPerSecond > 60
    }
    
    private func setupLowPowerModeObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    // MARK: - Performance Optimizations
    
    func optimizedAnimationDuration(base: TimeInterval) -> TimeInterval {
        let duration = base * (deviceClass.shouldReduceMotion ? 0.5 : 1.0)
        return isLowPowerModeEnabled ? duration * 0.7 : duration
    }
    
    func shouldUseReducedAnimations() -> Bool {
        return deviceClass.shouldReduceMotion || isLowPowerModeEnabled
    }
    
    func recommendedImageQuality() -> CGFloat {
        switch deviceClass {
        case .iPhoneSE:
            return isLowPowerModeEnabled ? 0.6 : 0.8
        case .iPhoneStandard, .iPhonePlus:
            return isLowPowerModeEnabled ? 0.7 : 0.9
        case .iPhonePro, .iPhoneProMax:
            return isLowPowerModeEnabled ? 0.8 : 1.0
        case .unknown:
            return 0.8
        }
    }
    
    func maxCacheSize() -> Int {
        let baseSize = 50 * 1024 * 1024 // 50MB base
        
        switch deviceClass {
        case .iPhoneSE:
            return baseSize / 2 // 25MB
        case .iPhoneStandard, .iPhonePlus:
            return baseSize // 50MB
        case .iPhonePro, .iPhoneProMax:
            return baseSize * 2 // 100MB
        case .unknown:
            return baseSize
        }
    }
    
    func shouldPreloadContent() -> Bool {
        return !isLowPowerModeEnabled && deviceClass != .iPhoneSE
    }
    
    // MARK: - UI Layout Optimizations
    
    func safeAreaInsets() -> EdgeInsets {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        
        let safeArea = window?.safeAreaInsets ?? .zero
        
        return EdgeInsets(
            top: safeArea.top,
            leading: safeArea.left,
            bottom: safeArea.bottom,
            trailing: safeArea.right
        )
    }
    
    func navigationBarHeight() -> CGFloat {
        switch deviceClass {
        case .iPhoneSE:
            return 44
        default:
            return 44 + safeAreaInsets().top
        }
    }
    
    func recommendedButtonSize() -> CGFloat {
        switch deviceClass {
        case .iPhoneSE:
            return 44 // Minimum touch target
        case .iPhoneStandard, .iPhonePro:
            return 48
        case .iPhonePlus, .iPhoneProMax:
            return 52
        case .unknown:
            return 44
        }
    }
    
    func recommendedSpacing() -> CGFloat {
        switch deviceClass {
        case .iPhoneSE:
            return 12
        case .iPhoneStandard, .iPhonePro:
            return 16
        case .iPhonePlus, .iPhoneProMax:
            return 20
        case .unknown:
            return 16
        }
    }
    
    // MARK: - Performance Settings
    
    func audioBufferSize() -> Int {
        switch deviceClass {
        case .iPhoneSE:
            return 512
        case .iPhoneStandard, .iPhonePlus:
            return 1024
        case .iPhonePro, .iPhoneProMax:
            return 2048
        case .unknown:
            return 1024
        }
    }
    
    func networkTimeoutInterval() -> TimeInterval {
        return isLowPowerModeEnabled ? 45.0 : 30.0
    }
    
    func shouldEnableHapticFeedback() -> Bool {
        return !isLowPowerModeEnabled
    }
    
    // MARK: - Memory Management
    
    func performMemoryWarningCleanup() {
        // Reduce cache sizes
        TranslationCache.shared.clearAll()
        
        // Reduce image quality
        UserDefaults.standard.set(0.5, forKey: "imageQuality")
        
        // Disable non-essential features
        if isLowPowerModeEnabled {
            UserDefaults.standard.set(false, forKey: "autoPlayTranslation")
            UserDefaults.standard.set(false, forKey: "enableAnimations")
        }
    }
    
    func memoryPressureLevel() -> MemoryPressureLevel {
        let memoryUsage = getMemoryUsage()
        
        if memoryUsage > 0.9 {
            return .critical
        } else if memoryUsage > 0.7 {
            return .high
        } else if memoryUsage > 0.5 {
            return .medium
        } else {
            return .low
        }
    }
    
    private func getMemoryUsage() -> Double {
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
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            return usedMemory / totalMemory
        }
        
        return 0.0
    }
}

enum MemoryPressureLevel {
    case low
    case medium
    case high
    case critical
    
    var shouldReducePerformance: Bool {
        switch self {
        case .low, .medium:
            return false
        case .high, .critical:
            return true
        }
    }
}