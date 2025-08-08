//
//  DesignConstants.swift
//  Mervyn Talks
//
//  Design constants for professional iOS layout with proper proportions
//

import SwiftUI
import UIKit

struct DesignConstants {
    
    // MARK: - Layout & Sizing
    
    struct Layout {
        static let screenPadding: CGFloat = 20
        static let contentSpacing: CGFloat = 24
        static let cardSpacing: CGFloat = 16
        static let elementSpacing: CGFloat = 12
        static let smallSpacing: CGFloat = 8
    }
    
    struct Sizing {
        // Microphone Button - PROPERLY SIZED (not oversized!)
        static let microphoneButtonSize: CGFloat = 130
        static let microphoneIconSize: CGFloat = 48
        
        // Language Selectors - Generous sizing for readability
        static let languageSelectorHeight: CGFloat = 56
        static let languageSelectorMinWidth: CGFloat = 140
        static let flagSize: CGFloat = 24
        
        // Swap Button
        static let swapButtonSize: CGFloat = 44
        static let swapIconSize: CGFloat = 20
        
        // Text Display Cards
        static let cardMinHeight: CGFloat = 80
        static let cardCornerRadius: CGFloat = 16
        
        // Status Indicator
        static let statusIndicatorHeight: CGFloat = 60
    }
    
    struct Typography {
        // App Title
        static let appTitleSize: CGFloat = 24
        static let appTitleWeight: Font.Weight = .bold
        
        // Language Selector
        static let languageNameSize: CGFloat = 16
        static let languageNameWeight: Font.Weight = .medium
        static let languageLabelSize: CGFloat = 12
        static let languageLabelWeight: Font.Weight = .regular
        
        // Status Text
        static let statusTitleSize: CGFloat = 18
        static let statusTitleWeight: Font.Weight = .semibold
        static let statusSubtitleSize: CGFloat = 14
        static let statusSubtitleWeight: Font.Weight = .regular
        
        // Card Content
        static let cardTitleSize: CGFloat = 14
        static let cardTitleWeight: Font.Weight = .medium
        static let cardContentSize: CGFloat = 16
        static let cardContentWeight: Font.Weight = .regular
    }
    
    // MARK: - Colors
    
    struct Colors {
        // Primary Colors
        static let primary = Color.blue
        static let primaryLight = Color.blue.opacity(0.1)
        static let accent = Color.orange
        
        // Button Colors
        static let microphoneDefault = LinearGradient(
            colors: [Color.blue, Color.blue.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
        static let microphoneRecording = LinearGradient(
            colors: [Color.red, Color.red.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
        
        // Background Colors
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let cardBackground = Color(.systemBackground)
        static let languageSelectorBackground = Color(.systemGray6)
        
        // Text Colors
        static let primaryText = Color(.label)
        static let secondaryText = Color(.secondaryLabel)
        static let tertiaryText = Color(.tertiaryLabel)
        
        // Status Colors
        static let recording = Color.red
        static let processing = Color.orange
        static let success = Color.green
    }
    
    // MARK: - Animations
    
    struct Animations {
        static let gentle = Animation.easeInOut(duration: 0.3)
        static let quick = Animation.easeInOut(duration: 0.2)
        static let bounce = Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let pulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    }
    
    // MARK: - Shadows
    
    struct Shadows {
        static let button = Shadow(
            color: Color.black.opacity(0.15),
            radius: 8,
            x: 0,
            y: 4
        )
        static let card = Shadow(
            color: Color.black.opacity(0.08),
            radius: 4,
            x: 0,
            y: 2
        )
        static let subtle = Shadow(
            color: Color.black.opacity(0.05),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

// MARK: - Shadow Helper

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    func applyShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
    
    func modernCardBackground() -> some View {
        self
            .background(DesignConstants.Colors.cardBackground)
            .cornerRadius(DesignConstants.Sizing.cardCornerRadius)
            .applyShadow(DesignConstants.Shadows.card)
    }
    
    func professionalPadding() -> some View {
        self.padding(.horizontal, DesignConstants.Layout.screenPadding)
    }
}