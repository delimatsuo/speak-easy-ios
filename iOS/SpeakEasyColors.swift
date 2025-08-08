//
//  SpeakEasyColors.swift
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
    
    // MARK: - Background Colors (Semantic - Auto-adapting)
    
    /// Primary background - uses system background
    static let speakEasyBackground = Color(.systemBackground)
    
    /// Secondary background for cards and elements
    static let speakEasySecondaryBackground = Color(.secondarySystemBackground)
    
    /// Tertiary background for nested elements
    static let speakEasyTertiaryBackground = Color(.tertiarySystemBackground)
    
    // MARK: - Text Colors (Semantic - Auto-adapting)
    
    /// Primary text color - uses system label
    static let speakEasyTextPrimary = Color(.label)
    
    /// Secondary text color - uses system secondary label
    static let speakEasyTextSecondary = Color(.secondaryLabel)
    
    /// Tertiary text color - uses system tertiary label
    static let speakEasyTextTertiary = Color(.tertiaryLabel)
    
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
    
    /// Processing/loading state color
    static let speakEasyProcessing = speakEasyBlue
    
    // MARK: - Adaptive Gradients
    
    /// Primary button gradient - adapts to system appearance
    static var speakEasyPrimaryGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [speakEasyTeal, speakEasyBlue]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
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
    
    /// Language picker background - FIXED: Now adaptive
    static let speakEasyPickerBackground: Color = {
        #if canImport(UIKit)
        return Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor.tertiarySystemBackground
            default:
                return UIColor(red: 0.95, green: 0.98, blue: 0.97, alpha: 1.0) // Light mint green
            }
        })
        #else
        return Color(.tertiarySystemBackground) // Fallback
        #endif
    }()

    // MARK: - On-Primary Colors (for text/icons on brand gradient)

    /// Primary content color for text/icons rendered on top of primary gradient or brand surfaces
    static let speakEasyOnPrimary: Color = {
        #if canImport(UIKit)
        return Color(UIColor { _ in UIColor.white })
        #else
        return Color.white
        #endif
    }()

    /// Secondary content color (slightly muted) for text on primary surfaces
    static let speakEasyOnPrimarySecondary: Color = {
        #if canImport(UIKit)
        return Color(UIColor { _ in UIColor(white: 1.0, alpha: 0.85) })
        #else
        return Color.white.opacity(0.85)
        #endif
    }()
}