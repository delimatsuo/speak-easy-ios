//
//  SpeakEasyColors.swift
//  UniversalTranslator
//
//  App color palette matching the icon design
//

import SwiftUI

extension Color {
    // MARK: - Primary Brand Colors (from icon gradient)
    
    /// Teal color from icon gradient start
    static let speakEasyTeal = Color(red: 0.00, green: 0.60, blue: 0.40)
    
    /// Blue color from icon gradient end
    static let speakEasyBlue = Color(red: 0.00, green: 0.40, blue: 0.75)
    
    // MARK: - UI Colors
    
    /// Primary accent color (teal)
    static let speakEasyAccent = speakEasyTeal
    
    /// Secondary accent color (blue)
    static let speakEasySecondary = speakEasyBlue
    
    /// Background gradient start
    static let speakEasyBackgroundLight = Color(red: 0.95, green: 0.98, blue: 0.97)
    
    /// Background gradient end
    static let speakEasyBackgroundDark = Color(red: 0.90, green: 0.96, blue: 0.98)
    
    /// Text on colored backgrounds
    static let speakEasyTextLight = Color.white
    
    /// Primary text color
    static let speakEasyTextPrimary = Color(red: 0.15, green: 0.15, blue: 0.20)
    
    /// Secondary text color
    static let speakEasyTextSecondary = Color(red: 0.45, green: 0.45, blue: 0.50)
    
    // MARK: - Semantic Colors
    
    /// Recording state color
    static let speakEasyRecording = Color(red: 0.95, green: 0.26, blue: 0.21)
    
    /// Success/Playing state color
    static let speakEasySuccess = speakEasyTeal
    
    /// Processing state color
    static let speakEasyProcessing = speakEasyBlue
    
    /// Error state color
    static let speakEasyError = Color(red: 0.85, green: 0.20, blue: 0.20)
    
    // MARK: - Component Colors
    
    /// Button background gradient
    static var speakEasyButtonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [speakEasyTeal, speakEasyBlue]),
            startPoint: .bottomTrailing,
            endPoint: .topLeading
        )
    }
    
    /// Subtle background gradient for cards
    static var speakEasyCardGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                speakEasyBackgroundLight,
                speakEasyBackgroundDark
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Main app background gradient
    static var speakEasyBackgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.98, green: 0.99, blue: 0.99),
                Color(red: 0.94, green: 0.97, blue: 0.98)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifiers for Consistent Styling

struct SpeakEasyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.speakEasyTextLight)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.speakEasyButtonGradient)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct SpeakEasyCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.speakEasyCardGradient)
            .cornerRadius(16)
            .shadow(color: Color.speakEasyBlue.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func speakEasyCard() -> some View {
        self.modifier(SpeakEasyCardStyle())
    }
}