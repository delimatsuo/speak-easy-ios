//
//  LanguageCardsSelector.swift
//  UniversalTranslator
//
//  Modern full-width language selector with stacked cards
//  Solves text truncation issues and provides clear visual hierarchy
//

import SwiftUI

struct LanguageCardsSelector: View {
    @Binding var source: String
    @Binding var target: String
    let languages: [Language]
    let onSwap: () -> Void
    let onTapSource: () -> Void
    let onTapTarget: () -> Void
    
    var body: some View {
        VStack(spacing: DesignConstants.Layout.cardSpacing) {
            // Source Language Card
            LanguageSelectionCard(
                languageCode: source,
                languages: languages,
                title: NSLocalizedString("speak_in", comment: "Label for source language selection"),
                subtitle: NSLocalizedString("source_language_hint", comment: "Hint text for source language"),
                cardType: .source,
                onTap: onTapSource
            )
            
            // Swap Button (Centered between cards)
            SwapLanguagesButton(action: onSwap)
            
            // Target Language Card
            LanguageSelectionCard(
                languageCode: target,
                languages: languages,
                title: NSLocalizedString("translate_to", comment: "Label for target language selection"),
                subtitle: NSLocalizedString("target_language_hint", comment: "Hint text for target language"),
                cardType: .target,
                onTap: onTapTarget
            )
        }
        .professionalPadding()
    }
}

// MARK: - Language Selection Card

struct LanguageSelectionCard: View {
    let languageCode: String
    let languages: [Language]
    let title: String
    let subtitle: String
    let cardType: LanguageCardType
    let onTap: () -> Void
    
    private var language: Language? {
        languages.first { $0.code == languageCode }
    }
    
    private var languageName: String {
        language?.name ?? Language.name(for: languageCode)
    }
    
    private var flagEmoji: String {
        language?.flag ?? "🌐"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Card Header with title and subtitle
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: DesignConstants.Typography.cardTitleSize, 
                                        weight: DesignConstants.Typography.cardTitleWeight))
                            .foregroundColor(.speakEasyTextSecondary)
                        
                        Spacer()
                        
                        // Card Type Indicator
                        Image(systemName: cardType.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(cardType.accentColor)
                    }
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.speakEasyTextTertiary)
                }
                
                // Language Display
                HStack(spacing: 16) {
                    // Flag with better sizing
                    Text(flagEmoji)
                        .font(.system(size: DesignConstants.Sizing.flagSize))
                        .frame(width: DesignConstants.Sizing.flagSize + 8, height: DesignConstants.Sizing.flagSize + 8)
                        .background(Circle().fill(Color.speakEasySecondaryBackground))
                    
                    // Language name - no truncation needed!
                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageName)
                            .font(.system(size: DesignConstants.Typography.languageNameSize, 
                                        weight: DesignConstants.Typography.languageNameWeight))
                            .foregroundColor(.speakEasyTextPrimary)
                            .multilineTextAlignment(.leading)
                        
                        Text(languageCode.uppercased())
                            .font(.system(size: DesignConstants.Typography.languageLabelSize, 
                                        weight: DesignConstants.Typography.languageLabelWeight))
                            .foregroundColor(.speakEasyTextTertiary)
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.speakEasyTextTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(minHeight: DesignConstants.Sizing.languageSelectorHeight + 20)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.Sizing.cardCornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignConstants.Sizing.cardCornerRadius)
                            .stroke(cardType.borderColor, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(LanguageCardButtonStyle())
    }
}

// MARK: - Swap Button

struct SwapLanguagesButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.speakEasyBorder, lineWidth: 1)
                    )
                    .applyShadow(DesignConstants.Shadows.button)
                
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.speakEasyPrimary)
            }
        }
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: UUID())
        .buttonStyle(SwapButtonStyle())
    }
}

// MARK: - Supporting Types

enum LanguageCardType {
    case source
    case target
    
    var iconName: String {
        switch self {
        case .source: return "mic.fill"
        case .target: return "speaker.wave.2.fill"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .source: return .speakEasyRecording
        case .target: return .speakEasyPrimary
        }
    }
    
    var borderColor: Color {
        switch self {
        case .source: return .speakEasyRecording.opacity(0.2)
        case .target: return .speakEasyPrimary.opacity(0.2)
        }
    }
}

// MARK: - Button Styles

struct LanguageCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SwapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            .rotationEffect(.degrees(configuration.isPressed ? 180 : 0))
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

struct LanguageCardsSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LanguageCardsSelector(
                source: .constant("en"),
                target: .constant("zh"),
                languages: Language.defaultLanguages,
                onSwap: {},
                onTapSource: {},
                onTapTarget: {}
            )
        }
        .padding()
        .background(Color.speakEasyBackground)
        .previewDevice("iPhone 14")
        .previewDisplayName("iPhone 14")
        
        VStack {
            LanguageCardsSelector(
                source: .constant("pt"),
                target: .constant("zh"),
                languages: Language.defaultLanguages,
                onSwap: {},
                onTapSource: {},
                onTapTarget: {}
            )
        }
        .padding()
        .background(Color.speakEasyBackground)
        .previewDevice("iPhone SE (3rd generation)")
        .previewDisplayName("iPhone SE - Long Names")
    }
}