//
//  WatchDesignSystem.swift
//  UniversalTranslator Watch App
//
//  Modern design system for Apple Watch UI with premium colors, gradients, and animations
//  Follows Apple's Human Interface Guidelines for watchOS
//

import SwiftUI
import WatchKit

// MARK: - Watch Color System

extension Color {
    
    // MARK: - Premium Brand Colors
    
    /// Primary brand gradient - Vibrant teal to blue
    static let watchPrimary = Color(red: 0.0, green: 0.65, blue: 0.45)
    static let watchPrimaryDark = Color(red: 0.0, green: 0.45, blue: 0.35)
    
    /// Secondary accent color - Electric blue
    static let watchAccent = Color(red: 0.0, green: 0.47, blue: 1.0)
    static let watchAccentDark = Color(red: 0.0, green: 0.35, blue: 0.85)
    
    // MARK: - State Colors
    
    /// Recording state - Vibrant red with energy
    static let watchRecording = Color(red: 1.0, green: 0.27, blue: 0.23)
    static let watchRecordingPulse = Color(red: 1.0, green: 0.47, blue: 0.43)
    
    /// Processing state - Animated blue
    static let watchProcessing = Color(red: 0.0, green: 0.48, blue: 1.0)
    
    /// Success state - Fresh green
    static let watchSuccess = Color(red: 0.20, green: 0.78, blue: 0.35)
    
    /// Warning state - Warm orange
    static let watchWarning = Color(red: 1.0, green: 0.58, blue: 0.0)
    
    /// Error state - Clear red
    static let watchError = Color(red: 1.0, green: 0.23, blue: 0.19)
    
    // MARK: - Background Colors
    
    /// Deep app background
    static let watchBackground = Color.black
    
    /// Card background with subtle elevation
    static let watchCardBackground = Color(white: 0.08)
    static let watchCardBackgroundElevated = Color(white: 0.12)
    
    /// Surface colors for different elevation levels
    static let watchSurface1 = Color(white: 0.05)
    static let watchSurface2 = Color(white: 0.08)
    static let watchSurface3 = Color(white: 0.12)
    
    // MARK: - Text Colors
    
    /// Primary text - Pure white
    static let watchTextPrimary = Color.white
    
    /// Secondary text - Soft gray
    static let watchTextSecondary = Color(white: 0.7)
    
    /// Tertiary text - Muted gray
    static let watchTextTertiary = Color(white: 0.5)
    
    /// Disabled text
    static let watchTextDisabled = Color(white: 0.3)
    
    // MARK: - Connection Status Colors
    
    /// Connected state - Subtle green
    static let watchConnected = Color(red: 0.20, green: 0.78, blue: 0.35)
    
    /// Disconnected state - Warm orange (less alarming than red)
    static let watchDisconnected = Color(red: 1.0, green: 0.58, blue: 0.0)
    
    /// Connecting state - Soft blue
    static let watchConnecting = Color(red: 0.0, green: 0.48, blue: 1.0)
}

// MARK: - Premium Gradients

struct WatchGradients {
    
    /// Main brand gradient - Teal to Blue
    static let primary = LinearGradient(
        gradient: Gradient(colors: [Color.watchPrimary, Color.watchAccent]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Dark variant for pressed states
    static let primaryDark = LinearGradient(
        gradient: Gradient(colors: [Color.watchPrimaryDark, Color.watchAccentDark]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Recording pulse gradient
    static let recording = LinearGradient(
        gradient: Gradient(colors: [Color.watchRecording, Color.watchRecordingPulse]),
        startPoint: .center,
        endPoint: .bottom
    )
    
    /// Background gradient for cards
    static let cardBackground = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color.watchSurface2, location: 0.0),
            .init(color: Color.watchSurface1, location: 1.0)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Microphone button gradient
    static let microphoneButton = RadialGradient(
        gradient: Gradient(colors: [
            Color.watchAccent.opacity(0.3),
            Color.watchAccent.opacity(0.1),
            Color.clear
        ]),
        center: .center,
        startRadius: 10,
        endRadius: 50
    )
}

// MARK: - Typography System

struct WatchTypography {
    
    /// Large title for main headings
    static let largeTitle = Font.system(size: 20, weight: .bold, design: .rounded)
    
    /// Title for section headings
    static let title = Font.system(size: 16, weight: .semibold, design: .rounded)
    
    /// Headline for important text
    static let headline = Font.system(size: 14, weight: .medium, design: .rounded)
    
    /// Body text for general content
    static let body = Font.system(size: 12, weight: .regular, design: .rounded)
    
    /// Caption for supplementary text
    static let caption = Font.system(size: 10, weight: .regular, design: .rounded)
    
    /// Small caption for minimal text
    static let caption2 = Font.system(size: 9, weight: .regular, design: .rounded)
    
    /// Button text
    static let button = Font.system(size: 12, weight: .medium, design: .rounded)
}

// MARK: - Spacing System

struct WatchSpacing {
    static let xs: CGFloat = 2
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
}

// MARK: - Corner Radius System

struct WatchCornerRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let round: CGFloat = 50
}

// MARK: - Animation System

struct WatchAnimations {
    
    /// Standard easing for UI transitions
    static let standard = Animation.easeInOut(duration: 0.3)
    
    /// Quick animation for button interactions
    static let quick = Animation.easeInOut(duration: 0.2)
    
    /// Smooth animation for state changes
    static let smooth = Animation.easeInOut(duration: 0.4)
    
    /// Recording pulse animation
    static let recordingPulse = Animation
        .easeInOut(duration: 1.0)
        .repeatForever(autoreverses: true)
    
    /// Gentle bounce for success states
    static let bounce = Animation
        .interactiveSpring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3)
    
    /// Waveform animation
    static let waveform = Animation
        .easeInOut(duration: 0.1)
        .repeatForever(autoreverses: true)
}

// MARK: - Shadow System

struct WatchShadows {
    
    /// Subtle elevation shadow
    static let card = (
        color: Color.black.opacity(0.3),
        radius: 4.0,
        x: 0.0,
        y: 2.0
    )
    
    /// Button press shadow
    static let button = (
        color: Color.black.opacity(0.2),
        radius: 2.0,
        x: 0.0,
        y: 1.0
    )
    
    /// Floating element shadow
    static let floating = (
        color: Color.black.opacity(0.4),
        radius: 8.0,
        x: 0.0,
        y: 4.0
    )
}

// MARK: - Haptic Feedback System

struct WatchHaptics {
    
    static func impact(_ style: WKHapticType) {
        WKInterfaceDevice.current().play(style)
    }
    
    static func selection() {
        WKInterfaceDevice.current().play(.click)
    }
    
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }
    
    static func error() {
        WKInterfaceDevice.current().play(.failure)
    }
    
    static func start() {
        WKInterfaceDevice.current().play(.start)
    }
    
    static func stop() {
        WKInterfaceDevice.current().play(.stop)
    }
}

// MARK: - Device Utilities

struct WatchDevice {
    
    /// Get the current watch screen size
    static var screenSize: CGSize {
        WKInterfaceDevice.current().screenBounds.size
    }
    
    /// Check if it's a larger watch (44mm or 45mm)
    static var isLargeWatch: Bool {
        screenSize.width >= 184
    }
    
    /// Get appropriate sizing multiplier
    static var sizeMultiplier: CGFloat {
        isLargeWatch ? 1.0 : 0.9
    }
}

// MARK: - View Modifiers

extension View {
    
    /// Apply watch card styling
    func watchCardStyle() -> some View {
        self
            .background(WatchGradients.cardBackground)
            .cornerRadius(WatchCornerRadius.lg)
            .shadow(
                color: WatchShadows.card.color,
                radius: WatchShadows.card.radius,
                x: WatchShadows.card.x,
                y: WatchShadows.card.y
            )
    }
    
    /// Apply watch button styling
    func watchButtonStyle(isPressed: Bool = false) -> some View {
        self
            .background(isPressed ? WatchGradients.primaryDark : WatchGradients.primary)
            .cornerRadius(WatchCornerRadius.lg)
            .shadow(
                color: WatchShadows.button.color,
                radius: WatchShadows.button.radius,
                x: WatchShadows.button.x,
                y: WatchShadows.button.y
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(WatchAnimations.quick, value: isPressed)
    }
    
    /// Apply premium text styling
    func watchTextStyle(_ level: WatchTextLevel = .body) -> some View {
        self
            .font(level.font)
            .foregroundColor(level.color)
    }
    
    /// Apply responsive sizing for different watch sizes
    func watchResponsive() -> some View {
        self.scaleEffect(WatchDevice.sizeMultiplier)
    }
}

// MARK: - Text Level System

enum WatchTextLevel {
    case title
    case headline
    case body
    case button
    case caption
    case caption2
    
    var font: Font {
        switch self {
        case .title: return WatchTypography.title
        case .headline: return WatchTypography.headline
        case .body: return WatchTypography.body
        case .button: return WatchTypography.button
        case .caption: return WatchTypography.caption
        case .caption2: return WatchTypography.caption2
        }
    }
    
    var color: Color {
        switch self {
        case .title: return Color.watchTextPrimary
        case .headline: return Color.watchTextPrimary
        case .body: return Color.watchTextSecondary
        case .button: return Color.watchTextPrimary
        case .caption: return Color.watchTextTertiary
        case .caption2: return Color.watchTextTertiary
        }
    }
}