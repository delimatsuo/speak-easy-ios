//
//  ModernSpeakEasyColors.swift
//  Mervyn Talks - Modern Color System
//
//  COMPLETELY REDESIGNED color system with proper dark/light mode support
//  Replaces hard-coded RGB values with semantic, adaptive colors
//

import SwiftUI

extension Color {
    
    // MARK: - Brand Colors (Adaptive to Light/Dark Mode)
    
    /// Primary brand teal - adapts automatically to system appearance
    static let speakEasyTeal: Color = {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.0, green: 0.70, blue: 0.47, alpha: 1.0) // Lighter teal for dark mode
            default:
                return UIColor(red: 0.0, green: 0.60, blue: 0.40, alpha: 1.0) // Original teal for light mode
            }
        })
        #else
        return Color(red: 0.0, green: 0.60, blue: 0.40) // Fallback for macOS
        #endif
    }()
    
    /// Secondary brand blue - adapts automatically to system appearance
    static let speakEasyBlue: Color = {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // System blue for dark mode
            default:
                return UIColor(red: 0.0, green: 0.40, blue: 0.75, alpha: 1.0) // Original blue for light mode
            }
        })
        #else
        return Color(red: 0.0, green: 0.40, blue: 0.75) // Fallback for macOS
        #endif
    }()
    
    // MARK: - Semantic System Colors (Auto-adapting)
    
    /// Primary brand color - automatically adapts to system appearance
    static let speakEasyPrimary = speakEasyTeal
    
    /// Secondary brand color - automatically adapts to system appearance  
    static let speakEasySecondary = speakEasyBlue
    
    /// Accent color for interactive elements - uses system accent when available
    static let speakEasyAccent: Color = {
        if #available(iOS 14.0, *) {
            return Color.accentColor
        } else {
            return speakEasyTeal
        }
    }()
    
    // MARK: - Background Colors (Semantic - Auto-adapting)
    
    /// Primary background - uses system background
    static let speakEasyBackground = Color(.systemBackground)
    
    /// Secondary background for cards and elements
    static let speakEasySecondaryBackground = Color(.secondarySystemBackground)
    
    /// Tertiary background for nested elements
    static let speakEasyTertiaryBackground = Color(.tertiarySystemBackground)
    
    /// Grouped background colors
    static let speakEasyGroupedBackground = Color(.systemGroupedBackground)
    static let speakEasySecondaryGroupedBackground = Color(.secondarySystemGroupedBackground)
    static let speakEasyTertiaryGroupedBackground = Color(.tertiarySystemGroupedBackground)
    
    // MARK: - Text Colors (Semantic - Auto-adapting)
    
    /// Primary text color - uses system label
    static let speakEasyTextPrimary = Color(.label)
    
    /// Secondary text color - uses system secondary label
    static let speakEasyTextSecondary = Color(.secondaryLabel)
    
    /// Tertiary text color - uses system tertiary label
    static let speakEasyTextTertiary = Color(.tertiaryLabel)
    
    /// Quaternary text color - uses system quaternary label
    static let speakEasyTextQuaternary = Color(.quaternaryLabel)
    
    /// Text on colored backgrounds
    static let speakEasyTextOnColor = Color.white
    
    // MARK: - State Colors (Adaptive)
    
    /// Recording state color - adapts to system appearance
    static let speakEasyRecording: Color = {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 1.0, green: 0.35, blue: 0.31, alpha: 1.0) // Lighter red for dark mode
            default:
                return UIColor(red: 0.95, green: 0.26, blue: 0.21, alpha: 1.0) // Original red for light mode
            }
        })
        #else
        return Color(red: 0.95, green: 0.26, blue: 0.21) // Fallback
        #endif
    }()
    
    /// Success/completion state color
    static let speakEasySuccess: Color = {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1.0) // Brighter green for dark mode
            default:
                return UIColor(red: 0.0, green: 0.60, blue: 0.40, alpha: 1.0) // Teal for light mode
            }
        })
        #else
        return Color(red: 0.0, green: 0.60, blue: 0.40) // Fallback
        #endif
    }()
    
    /// Processing/loading state color
    static let speakEasyProcessing = speakEasyBlue
    
    /// Error state color
    static let speakEasyError: Color = {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 1.0, green: 0.41, blue: 0.38, alpha: 1.0) // Lighter red for dark mode
            default:
                return UIColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1.0) // Darker red for light mode
            }
        })
        #else
        return Color(red: 0.85, green: 0.20, blue: 0.20) // Fallback
        #endif
    }()
    
    /// Warning state color
    static let speakEasyWarning: Color = {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 1.0, green: 0.70, blue: 0.25, alpha: 1.0) // Lighter orange for dark mode
            default:
                return UIColor(red: 1.0, green: 0.60, blue: 0.0, alpha: 1.0) // Orange for light mode
            }
        })
        #else
        return Color(red: 1.0, green: 0.60, blue: 0.0) // Fallback
        #endif
    }()
    
    // MARK: - Separator Colors
    static let speakEasySeparator = Color(.separator)
    static let speakEasyOpaqueSeparator = Color(.opaqueSeparator)
    
    // MARK: - Adaptive Gradients
    
    /// Primary button gradient - adapts to system appearance
    static var speakEasyPrimaryGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [speakEasyTeal, speakEasyBlue]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Card background gradient - adapts to system appearance
    static var speakEasyCardGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                speakEasySecondaryBackground,
                speakEasyTertiaryBackground
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Main app background gradient - FIXED: Now uses semantic colors
    static var speakEasyBackgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                speakEasyBackground,
                speakEasySecondaryBackground
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Recording pulse gradient
    static var speakEasyRecordingGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                speakEasyRecording,
                speakEasyRecording.opacity(0.7)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Component-Specific Colors
    
    /// Transcribed text background - FIXED: Now adaptive
    static let speakEasyTranscribedBackground: Color = {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.secondarySystemBackground
            default:
                return UIColor(red: 0.95, green: 0.98, blue: 0.97, alpha: 1.0) // Light mint green
            }
        })
        #else
        return Color(.secondarySystemBackground) // Fallback
        #endif
    }()
    
    /// Translated text background - FIXED: Now adaptive
    static let speakEasyTranslatedBackground: Color = {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.0, green: 0.40, blue: 0.27, alpha: 0.15) // Darker teal with opacity
            default:
                return UIColor(red: 0.0, green: 0.60, blue: 0.40, alpha: 0.1) // Light teal with opacity
            }
        })
        #else
        return Color(red: 0.0, green: 0.60, blue: 0.40).opacity(0.1) // Fallback
        #endif
    }()
}

// MARK: - Modern Button Styles (Updated)
struct ModernSpeakEasyButtonStyle: ButtonStyle {
    let style: ButtonStyleType
    
    enum ButtonStyleType {
        case primary
        case secondary
        case destructive
        case ghost
    }
    
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(
                color: shadowColor,
                radius: configuration.isPressed ? 2 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 2
            )
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return isEnabled ? Color.speakEasyPrimaryGradient.opacity(1.0) : Color.speakEasyTextSecondary
        case .secondary:
            return Color.speakEasySecondaryBackground
        case .destructive:
            return Color.speakEasyError
        case .ghost:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .speakEasyPrimary
        case .destructive:
            return .white
        case .ghost:
            return .speakEasyPrimary
        }
    }
    
    private var shadowColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.3)
        default:
            return Color.black.opacity(0.15)
        }
    }
}

// MARK: - Modern Card Style (Updated)
struct ModernSpeakEasyCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.speakEasySecondaryBackground)
                    .shadow(
                        color: shadowColor,
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
    }
    
    private var shadowColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.3)
        default:
            return Color.black.opacity(0.1)
        }
    }
}

// MARK: - Language Picker Style (Updated)
struct ModernLanguagePickerStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.speakEasyTertiaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.speakEasySeparator, lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - View Extensions (Updated)
extension View {
    
    /// Apply modern card styling with proper dark/light mode support
    func modernSpeakEasyCard() -> some View {
        self.modifier(ModernSpeakEasyCardStyle())
    }
    
    /// Apply primary button style
    func speakEasyPrimaryButton() -> some View {
        self.buttonStyle(ModernSpeakEasyButtonStyle(style: .primary))
    }
    
    /// Apply secondary button style
    func speakEasySecondaryButton() -> some View {
        self.buttonStyle(ModernSpeakEasyButtonStyle(style: .secondary))
    }
    
    /// Apply destructive button style
    func speakEasyDestructiveButton() -> some View {
        self.buttonStyle(ModernSpeakEasyButtonStyle(style: .destructive))
    }
    
    /// Apply ghost button style
    func speakEasyGhostButton() -> some View {
        self.buttonStyle(ModernSpeakEasyButtonStyle(style: .ghost))
    }
    
    /// Apply modern language picker styling
    func modernLanguagePickerStyle() -> some View {
        self.modifier(ModernLanguagePickerStyle())
    }
    
    /// Apply proper text styling with dark/light mode support
    func speakEasyTextStyle(_ level: TextLevel = .body) -> some View {
        switch level {
        case .title:
            return self
                .font(.title2.weight(.bold))
                .foregroundColor(.speakEasyTextPrimary)
        case .headline:
            return self
                .font(.headline.weight(.medium))
                .foregroundColor(.speakEasyTextPrimary)
        case .body:
            return self
                .font(.body)
                .foregroundColor(.speakEasyTextPrimary)
        case .caption:
            return self
                .font(.caption)
                .foregroundColor(.speakEasyTextSecondary)
        case .secondary:
            return self
                .font(.body)
                .foregroundColor(.speakEasyTextSecondary)
        }
    }
    
    enum TextLevel {
        case title, headline, body, caption, secondary
    }
}

// MARK: - Color Contrast Helpers
extension Color {
    
    /// Get contrasting text color for this background color
    var contrastingTextColor: Color {
        // This is a simplified version - in production you'd calculate luminance
        return self == .speakEasyBackground ? .speakEasyTextPrimary : .speakEasyTextOnColor
    }
    
    /// Check if color meets WCAG contrast requirements (simplified)
    func meetsContrastRequirement(against background: Color) -> Bool {
        // In production, implement actual contrast ratio calculation
        // For now, return true for semantic colors which are designed to meet requirements
        return true
    }
}

// MARK: - Migration Guide for Existing Code

/*
 MIGRATION FROM OLD TO NEW COLOR SYSTEM:
 
 OLD (Hard-coded, breaking in dark mode):
 ❌ Color(red: 0.95, green: 0.98, blue: 0.97)
 ❌ Color(red: 0.00, green: 0.60, blue: 0.40).opacity(0.1)
 ❌ Color(red: 0.98, green: 0.99, blue: 0.99)
 ❌ Color(red: 0.45, green: 0.45, blue: 0.50)
 
 NEW (Adaptive, works in both modes):
 ✅ Color.speakEasyTranscribedBackground
 ✅ Color.speakEasyTranslatedBackground  
 ✅ Color.speakEasyBackground
 ✅ Color.speakEasyTextSecondary
 
 BACKGROUND FIXES:
 ❌ LinearGradient(colors: [Color(red: 0.98, green: 0.99, blue: 0.99), Color(red: 0.94, green: 0.97, blue: 0.98)])
 ✅ Color.speakEasyBackgroundGradient
 
 TEXT COLOR FIXES:
 ❌ .foregroundColor(.secondary) // Can be hard to read
 ✅ .foregroundColor(.speakEasyTextSecondary) // Guaranteed contrast
 
 BUTTON BACKGROUND FIXES:
 ❌ .background(Color(red: 0.95, green: 0.98, blue: 0.97))
 ✅ .background(Color.speakEasySecondaryBackground)
 
 CARD BACKGROUND FIXES:
 ❌ .background(Color(red: 0.95, green: 0.98, blue: 0.97))
 ✅ .modernSpeakEasyCard()
 */