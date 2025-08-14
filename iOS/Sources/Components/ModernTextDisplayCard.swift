//
//  ModernTextDisplayCard.swift
//  Mervyn Talks
//
//  Professional text display cards with clean design
//

import SwiftUI

// MARK: - Combined Display Card expected by ContentView

struct ModernTextDisplayCard: View {
    let transcribedText: String
    let translatedText: String
    let onReplay: (() -> Void)?
    let canReplay: Bool

    var body: some View {
        VStack(spacing: DesignConstants.Layout.cardSpacing) {
            if !transcribedText.isEmpty {
                ModernTextCard(
                    title: "You said:",
                    text: transcribedText,
                    icon: "mic.fill",
                    backgroundColor: .speakEasyTranscribedBackground,
                    showReplayButton: false,
                    onReplay: nil
                )
            }

            if !translatedText.isEmpty {
                ModernTextCard(
                    title: "Translation:",
                    text: translatedText,
                    icon: "speaker.wave.2.fill",
                    backgroundColor: .speakEasyTranslatedBackground,
                    showReplayButton: canReplay,
                    onReplay: onReplay
                )
            }
        }
    }
}

// MARK: - Single Text Card building block

struct ModernTextCard: View {
    let title: String
    let text: String
    let icon: String
    let backgroundColor: Color
    let showReplayButton: Bool
    let onReplay: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignConstants.Layout.elementSpacing) {
            // Header with icon and title
            HStack(spacing: DesignConstants.Layout.smallSpacing) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignConstants.Colors.primary)
                
                Text(title)
                    .font(.system(size: DesignConstants.Typography.cardTitleSize, 
                                weight: DesignConstants.Typography.cardTitleWeight))
                    .foregroundColor(DesignConstants.Colors.secondaryText)
                
                Spacer()
                
                // Replay button
                if showReplayButton, let replayAction = onReplay {
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        replayAction()
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(DesignConstants.Colors.primary)
                    }
                    .accessibilityLabel("Replay translation")
                }
            }
            
            // Text Content
            ScrollView {
                Text(text)
                    .font(.system(size: DesignConstants.Typography.cardContentSize, 
                                weight: DesignConstants.Typography.cardContentWeight))
                    .foregroundColor(DesignConstants.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: DesignConstants.Sizing.cardMinHeight, maxHeight: 120)
        }
        .padding(DesignConstants.Layout.cardSpacing)
        .background(backgroundColor)
        .cornerRadius(DesignConstants.Sizing.cardCornerRadius)
        .applyShadow(DesignConstants.Shadows.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(text)")
    }
}

// MARK: - Swap Languages Button

struct ModernSwapButton: View {
    let sourceLanguage: String
    let targetLanguage: String
    let action: () -> Void
    
    @State private var rotation: Double = 0
    
    private var isDisabled: Bool {
        sourceLanguage == targetLanguage
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: handleSwap) {
                Image(systemName: "arrow.2.circlepath")
                    .font(.system(size: DesignConstants.Sizing.swapIconSize, weight: .medium))
                    .foregroundColor(isDisabled ? DesignConstants.Colors.tertiaryText : DesignConstants.Colors.primary)
                    .frame(width: DesignConstants.Sizing.swapButtonSize, 
                           height: DesignConstants.Sizing.swapButtonSize)
                    .background(
                        Circle()
                            .fill(DesignConstants.Colors.primaryLight)
                            .opacity(isDisabled ? 0.3 : 1.0)
                    )
                    .rotationEffect(.degrees(rotation))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDisabled)
            .accessibilityLabel("Swap languages")
            .accessibilityHint(isDisabled ? "Cannot swap identical languages" : "Tap to swap source and target languages")
            
            // Language codes indicator
            Text("\(sourceLanguage.uppercased()) ⇄ \(targetLanguage.uppercased())")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignConstants.Colors.tertiaryText)
                .opacity(isDisabled ? 0.5 : 1.0)
        }
    }
    
    private func handleSwap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(DesignConstants.Animations.bounce) {
            rotation += 180
        }
        
        action()
    }
}

// MARK: - Preview

#if DEBUG
struct ModernTextDisplayCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ModernTextDisplayCard(
                transcribedText: "Hello, how are you today? I hope you're having a wonderful day!",
                translatedText: "Hola, ¿cómo estás hoy? ¡Espero que tengas un día maravilloso!",
                onReplay: {},
                canReplay: true
            )
            
            ModernSwapButton(
                sourceLanguage: "en",
                targetLanguage: "es",
                action: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif