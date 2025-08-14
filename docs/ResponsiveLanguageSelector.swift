//
//  ResponsiveLanguageSelector.swift
//  UniversalTranslator
//
//  Responsive language selector that adapts to all iPhone screen sizes
//  with smart layout decisions and accessibility features
//

import SwiftUI

struct ResponsiveLanguageSelector: View {
    @Binding var source: String
    @Binding var target: String
    let languages: [Language]
    let onSwap: () -> Void
    let onTapSource: () -> Void
    let onTapTarget: () -> Void
    
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width
    
    // Dynamic layout decisions based on screen size
    private var isCompactScreen: Bool {
        screenWidth < 375 // iPhone SE and smaller
    }
    
    private var cardSpacing: CGFloat {
        isCompactScreen ? 12 : DesignConstants.Layout.cardSpacing
    }
    
    private var cardPadding: CGFloat {
        isCompactScreen ? 16 : 20
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: cardSpacing) {
                // Source Language Card
                ResponsiveLanguageCard(
                    languageCode: source,
                    languages: languages,
                    title: NSLocalizedString("speak_in", comment: "Label for source language selection"),
                    subtitle: NSLocalizedString("source_language_hint", comment: "Hint text for source language"),
                    cardType: .source,
                    isCompact: isCompactScreen,
                    onTap: onTapSource
                )
                
                // Swap Button with smart positioning
                SwapLanguagesButton(
                    action: onSwap,
                    isCompact: isCompactScreen
                )
                
                // Target Language Card  
                ResponsiveLanguageCard(
                    languageCode: target,
                    languages: languages,
                    title: NSLocalizedString("translate_to", comment: "Label for target language selection"),
                    subtitle: NSLocalizedString("target_language_hint", comment: "Hint text for target language"),
                    cardType: .target,
                    isCompact: isCompactScreen,
                    onTap: onTapTarget
                )
            }
            .padding(.horizontal, isCompactScreen ? 16 : DesignConstants.Layout.screenPadding)
            .onAppear {
                screenWidth = geometry.size.width
            }
            .onChange(of: geometry.size.width) { newWidth in
                screenWidth = newWidth
            }
        }
    }
}

// MARK: - Responsive Language Card

struct ResponsiveLanguageCard: View {
    let languageCode: String
    let languages: [Language]
    let title: String
    let subtitle: String
    let cardType: LanguageCardType
    let isCompact: Bool
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
    
    // Dynamic font sizes based on screen size
    private var titleFontSize: CGFloat {
        isCompact ? 13 : DesignConstants.Typography.cardTitleSize
    }
    
    private var languageNameFontSize: CGFloat {
        isCompact ? 15 : DesignConstants.Typography.languageNameSize
    }
    
    private var flagSize: CGFloat {
        isCompact ? 20 : DesignConstants.Sizing.flagSize
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
                // Compact header for small screens
                if isCompact {
                    compactHeader
                } else {
                    standardHeader
                }
                
                // Language display - adapts to content
                HStack(spacing: isCompact ? 12 : 16) {
                    // Flag with smart sizing
                    Text(flagEmoji)
                        .font(.system(size: flagSize))
                        .frame(width: flagSize + 8, height: flagSize + 8)
                        .background(
                            Circle()
                                .fill(Color.speakEasySecondaryBackground)
                                .overlay(
                                    Circle()
                                        .stroke(cardType.borderColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                    
                    // Language info - smart text handling
                    VStack(alignment: .leading, spacing: 2) {
                        Text(languageName)
                            .font(.system(size: languageNameFontSize, weight: .semibold))
                            .foregroundColor(.speakEasyTextPrimary)
                            .lineLimit(isCompact ? 1 : 2) // Allow wrap on larger screens
                            .minimumScaleFactor(isCompact ? 0.8 : 1.0) // Scale down if needed on small screens
                        
                        if !isCompact || languageName.count <= 10 {
                            Text(languageCode.uppercased())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.speakEasyTextTertiary)
                        }
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Selection indicator with better contrast
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: isCompact ? 16 : 18, weight: .medium))
                        .foregroundStyle(.white, cardType.accentColor)
                }
            }
            .padding(.horizontal, isCompact ? 16 : 20)
            .padding(.vertical, isCompact ? 12 : 16)
            .frame(minHeight: isCompact ? 60 : 76)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 12 : DesignConstants.Sizing.cardCornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: isCompact ? 12 : DesignConstants.Sizing.cardCornerRadius)
                            .stroke(cardType.borderColor, lineWidth: isCompact ? 1.5 : 2)
                    )
            )
        }
        .buttonStyle(ResponsiveCardButtonStyle())
        .accessibilityLabel("\(title): \(languageName)")
        .accessibilityHint("Tap to select a different \(cardType == .source ? "source" : "target") language")
    }
    
    @ViewBuilder
    private var compactHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: cardType.iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(cardType.accentColor)
                
                Text(title)
                    .font(.system(size: titleFontSize, weight: .medium))
                    .foregroundColor(.speakEasyTextSecondary)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var standardHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: titleFontSize, weight: .medium))
                    .foregroundColor(.speakEasyTextSecondary)
                
                Spacer()
                
                Image(systemName: cardType.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(cardType.accentColor)
            }
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.speakEasyTextTertiary)
        }
    }
}

// MARK: - Responsive Swap Button

struct SwapLanguagesButton: View {
    let action: () -> Void
    let isCompact: Bool
    
    private var buttonSize: CGFloat {
        isCompact ? 44 : 50
    }
    
    private var iconSize: CGFloat {
        isCompact ? 18 : 20
    }
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                action()
            }) {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: buttonSize, height: buttonSize)
                        .overlay(
                            Circle()
                                .stroke(Color.speakEasyBorder, lineWidth: 1)
                        )
                        .applyShadow(DesignConstants.Shadows.button)
                    
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundColor(.speakEasyPrimary)
                }
            }
            .buttonStyle(ResponsiveSwapButtonStyle())
            .accessibilityLabel("Swap languages")
            .accessibilityHint("Swaps the source and target languages")
            Spacer()
        }
    }
}

// MARK: - Button Styles

struct ResponsiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ResponsiveSwapButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.1 : 1.0)
            .rotationEffect(.degrees(configuration.isPressed ? 180 : 0))
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Enhanced Color Extensions

extension Color {
    static let speakEasyBorder = Color(.systemGray4)
    static let speakEasySecondaryBackground = Color(.secondarySystemBackground)
    static let speakEasyTextTertiary = Color(.tertiaryLabel)
}

// MARK: - Preview

struct ResponsiveLanguageSelector_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // iPhone 14 Pro Max
            ResponsiveLanguageSelector(
                source: .constant("en"),
                target: .constant("zh"),
                languages: Language.defaultLanguages,
                onSwap: {},
                onTapSource: {},
                onTapTarget: {}
            )
            .padding()
            .background(Color.speakEasyBackground)
            .previewDevice("iPhone 14 Pro Max")
            .previewDisplayName("iPhone 14 Pro Max")
            
            // iPhone SE (Small screen)
            ResponsiveLanguageSelector(
                source: .constant("pt"),
                target: .constant("zh"),
                languages: Language.defaultLanguages,
                onSwap: {},
                onTapSource: {},
                onTapTarget: {}
            )
            .padding()
            .background(Color.speakEasyBackground)
            .previewDevice("iPhone SE (3rd generation)")
            .previewDisplayName("iPhone SE - Compact")
            
            // Dark mode test
            ResponsiveLanguageSelector(
                source: .constant("ar"),
                target: .constant("hi"),
                languages: Language.defaultLanguages,
                onSwap: {},
                onTapSource: {},
                onTapTarget: {}
            )
            .padding()
            .background(Color.speakEasyBackground)
            .previewDevice("iPhone 14")
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}