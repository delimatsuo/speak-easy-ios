//
//  ResponsiveDesignHelper.swift
//  Mervyn Talks
//
//  Comprehensive responsive design system for iOS 17
//  Handles screen sizes, device detection, and adaptive layouts
//

import SwiftUI
import UIKit

// MARK: - Device Detection and Screen Metrics

struct DeviceInfo {
    static let shared = DeviceInfo()
    
    private init() {}
    
    // MARK: - Screen Properties
    
    var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    
    var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
    
    var screenScale: CGFloat {
        UIScreen.main.scale
    }
    
    // MARK: - Device Type Detection
    
    var deviceType: DeviceType {
        let idiom = UIDevice.current.userInterfaceIdiom
        let screenSize = UIScreen.main.bounds.size
        let screenHeight = max(screenSize.width, screenSize.height)
        let screenWidth = min(screenSize.width, screenSize.height)
        
        switch idiom {
        case .phone:
            // iPhone classification by screen height
            switch screenHeight {
            case 0...667: return .iPhoneSE  // iPhone SE, 8, 7, 6s, 6
            case 668...735: return .iPhoneStandard  // iPhone 8 Plus, 7 Plus, 6s Plus, 6 Plus
            case 736...811: return .iPhoneX  // iPhone X, XS, 11 Pro
            case 812...895: return .iPhoneXR  // iPhone XR, 11
            case 896...925: return .iPhoneProMax  // iPhone XS Max, 11 Pro Max
            case 926...: return .iPhoneProMax  // iPhone 12 Pro Max and newer
            default: return .iPhoneStandard
            }
        case .pad:
            if screenWidth >= 1024 {
                return .iPadPro12  // iPad Pro 12.9"
            } else if screenWidth >= 834 {
                return .iPadPro11  // iPad Pro 11", iPad Air
            } else {
                return .iPad  // Regular iPad, iPad mini
            }
        default:
            return .iPhoneStandard
        }
    }
    
    // MARK: - Safe Area Properties
    
    var safeAreaInsets: UIEdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets
        }
        return .zero
    }
    
    var topSafeArea: CGFloat {
        safeAreaInsets.top
    }
    
    var bottomSafeArea: CGFloat {
        safeAreaInsets.bottom
    }
    
    var hasNotch: Bool {
        topSafeArea > 20
    }
    
    var hasDynamicIsland: Bool {
        // Dynamic Island detection (iPhone 14 Pro series and newer)
        deviceType == .iPhoneProMax && topSafeArea >= 59
    }
    
    // MARK: - Screen Size Categories
    
    var screenSizeCategory: ScreenSizeCategory {
        let height = screenHeight
        
        switch deviceType {
        case .iPhoneSE:
            return .compact
        case .iPhoneStandard:
            return .regular
        case .iPhoneX, .iPhoneXR:
            return .large
        case .iPhoneProMax:
            return .extraLarge
        case .iPad, .iPadPro11, .iPadPro12:
            return .extraLarge
        }
    }
}

// MARK: - Device Type Enumeration

enum DeviceType {
    case iPhoneSE           // iPhone SE, 8, 7, 6s, 6 (375x667 points)
    case iPhoneStandard     // iPhone 8 Plus, 7 Plus, 6s Plus, 6 Plus (414x736 points)
    case iPhoneX            // iPhone X, XS, 11 Pro (375x812 points)
    case iPhoneXR           // iPhone XR, 11 (414x896 points)
    case iPhoneProMax       // iPhone XS Max, 11 Pro Max, 12 Pro Max+ (414x896+ points)
    case iPad               // Regular iPad, iPad mini
    case iPadPro11          // iPad Pro 11", iPad Air
    case iPadPro12          // iPad Pro 12.9"
    
    var displayName: String {
        switch self {
        case .iPhoneSE: return "iPhone SE"
        case .iPhoneStandard: return "iPhone Standard"
        case .iPhoneX: return "iPhone X Series"
        case .iPhoneXR: return "iPhone XR/11"
        case .iPhoneProMax: return "iPhone Pro Max"
        case .iPad: return "iPad"
        case .iPadPro11: return "iPad Pro 11\""
        case .iPadPro12: return "iPad Pro 12.9\""
        }
    }
}

// MARK: - Screen Size Categories

enum ScreenSizeCategory {
    case compact        // iPhone SE
    case regular        // iPhone 8, 8 Plus
    case large          // iPhone X, XR, 11
    case extraLarge     // iPhone Pro Max, iPad
    
    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .regular: return "Regular"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
}

// MARK: - Responsive Design Utilities

struct ResponsiveDesign {
    private let deviceInfo = DeviceInfo.shared
    
    // MARK: - Adaptive Sizing
    
    /// Returns adaptive button size based on device screen size
    func buttonSize(baseSize: CGFloat = 150) -> CGFloat {
        let screenWidth = deviceInfo.screenWidth
        let scaleFactor: CGFloat
        
        switch deviceInfo.screenSizeCategory {
        case .compact:
            scaleFactor = 0.85  // 85% of base size for compact screens
        case .regular:
            scaleFactor = 1.0   // Base size for regular screens
        case .large:
            scaleFactor = 1.1   // 110% of base size for large screens
        case .extraLarge:
            scaleFactor = 1.2   // 120% of base size for extra large screens
        }
        
        return baseSize * scaleFactor
    }
    
    /// Returns adaptive pulse circle size based on button size
    func pulseSize(forButtonSize buttonSize: CGFloat) -> CGFloat {
        return buttonSize * 1.3
    }
    
    /// Returns adaptive font size based on device and context
    func fontSize(for style: FontStyle) -> CGFloat {
        let baseSizes: [FontStyle: CGFloat] = [
            .title: 28,
            .headline: 20,
            .body: 16,
            .caption: 12,
            .microphone: 60
        ]
        
        guard let baseSize = baseSizes[style] else { return 16 }
        
        let scaleFactor: CGFloat
        switch deviceInfo.screenSizeCategory {
        case .compact:
            scaleFactor = 0.9
        case .regular:
            scaleFactor = 1.0
        case .large:
            scaleFactor = 1.05
        case .extraLarge:
            scaleFactor = 1.1
        }
        
        return baseSize * scaleFactor
    }
    
    /// Returns adaptive spacing based on screen size
    func spacing(for size: SpacingSize) -> CGFloat {
        let baseSizes: [SpacingSize: CGFloat] = [
            .extraSmall: 4,
            .small: 8,
            .medium: 16,
            .large: 24,
            .extraLarge: 32
        ]
        
        guard let baseSize = baseSizes[size] else { return 16 }
        
        let scaleFactor: CGFloat
        switch deviceInfo.screenSizeCategory {
        case .compact:
            scaleFactor = 0.8
        case .regular:
            scaleFactor = 1.0
        case .large:
            scaleFactor = 1.1
        case .extraLarge:
            scaleFactor = 1.2
        }
        
        return baseSize * scaleFactor
    }
    
    /// Returns adaptive padding for safe areas
    func safeAreaPadding() -> EdgeInsets {
        EdgeInsets(
            top: max(deviceInfo.topSafeArea, 8),
            leading: spacing(for: .medium),
            bottom: max(deviceInfo.bottomSafeArea, 8),
            trailing: spacing(for: .medium)
        )
    }
    
    /// Returns adaptive corner radius based on component size
    func cornerRadius(for size: CornerRadiusSize) -> CGFloat {
        let baseSizes: [CornerRadiusSize: CGFloat] = [
            .small: 6,
            .medium: 10,
            .large: 16,
            .extraLarge: 24,
            .circular: 50
        ]
        
        return baseSizes[size] ?? 10
    }
    
    // MARK: - Layout Helpers
    
    /// Returns whether the current orientation is landscape
    var isLandscape: Bool {
        deviceInfo.screenWidth > deviceInfo.screenHeight
    }
    
    /// Returns optimal number of columns for grid layouts
    func gridColumns() -> Int {
        switch deviceInfo.deviceType {
        case .iPhoneSE:
            return isLandscape ? 3 : 2
        case .iPhoneStandard, .iPhoneX:
            return isLandscape ? 4 : 2
        case .iPhoneXR, .iPhoneProMax:
            return isLandscape ? 4 : 3
        case .iPad, .iPadPro11, .iPadPro12:
            return isLandscape ? 5 : 4
        }
    }
    
    /// Returns adaptive card width for optimal readability
    func cardWidth() -> CGFloat {
        let screenWidth = deviceInfo.screenWidth
        let horizontalPadding = spacing(for: .medium) * 2
        
        switch deviceInfo.deviceType {
        case .iPhoneSE, .iPhoneStandard, .iPhoneX, .iPhoneXR, .iPhoneProMax:
            return screenWidth - horizontalPadding
        case .iPad, .iPadPro11, .iPadPro12:
            return min(screenWidth * 0.7, 600) // Max 600pt width on iPad
        }
    }
}

// MARK: - Style Enumerations

enum FontStyle {
    case title
    case headline
    case body
    case caption
    case microphone
}

enum SpacingSize {
    case extraSmall
    case small
    case medium
    case large
    case extraLarge
}

enum CornerRadiusSize {
    case small
    case medium
    case large
    case extraLarge
    case circular
}

// MARK: - SwiftUI View Modifiers

struct ResponsiveFrame: ViewModifier {
    let responsive = ResponsiveDesign()
    let baseSize: CGFloat
    
    func body(content: Content) -> some View {
        let adaptiveSize = responsive.buttonSize(baseSize: baseSize)
        return content
            .frame(width: adaptiveSize, height: adaptiveSize)
    }
}

struct ResponsivePadding: ViewModifier {
    let responsive = ResponsiveDesign()
    let size: SpacingSize
    
    func body(content: Content) -> some View {
        let padding = responsive.spacing(for: size)
        return content
            .padding(padding)
    }
}

struct ResponsiveCornerRadius: ViewModifier {
    let responsive = ResponsiveDesign()
    let size: CornerRadiusSize
    
    func body(content: Content) -> some View {
        let radius = responsive.cornerRadius(for: size)
        return content
            .cornerRadius(radius)
    }
}

// MARK: - SwiftUI Extensions

extension View {
    func responsiveFrame(baseSize: CGFloat = 150) -> some View {
        modifier(ResponsiveFrame(baseSize: baseSize))
    }
    
    func responsivePadding(_ size: SpacingSize = .medium) -> some View {
        modifier(ResponsivePadding(size: size))
    }
    
    func responsiveCornerRadius(_ size: CornerRadiusSize = .medium) -> some View {
        modifier(ResponsiveCornerRadius(size: size))
    }
    
    func adaptiveSafeArea() -> some View {
        let responsive = ResponsiveDesign()
        let padding = responsive.safeAreaPadding()
        return self.padding(padding)
    }
}

// MARK: - Preview Support

#if DEBUG
struct ResponsiveDesignHelper_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Device: \(DeviceInfo.shared.deviceType.displayName)")
                .font(.headline)
            
            Text("Screen Category: \(DeviceInfo.shared.screenSizeCategory.displayName)")
                .font(.subheadline)
            
            Text("Has Notch: \(DeviceInfo.shared.hasNotch ? "Yes" : "No")")
                .font(.caption)
            
            Text("Dynamic Island: \(DeviceInfo.shared.hasDynamicIsland ? "Yes" : "No")")
                .font(.caption)
            
            Circle()
                .fill(Color.blue)
                .responsiveFrame(baseSize: 100)
            
            Rectangle()
                .fill(Color.green)
                .responsiveFrame(baseSize: 200)
                .responsiveCornerRadius(.large)
        }
        .responsivePadding(.large)
    }
}
#endif