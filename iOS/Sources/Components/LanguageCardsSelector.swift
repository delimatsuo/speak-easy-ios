//
//  LanguageCardsSelector.swift
//  UniversalTranslator
//
//  Full-width language card selector with no text truncation
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
        VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 8 : 12) {
            // Source Language Card
            LanguageCard(
                label: NSLocalizedString("speak_in", comment: "Source language label"),
                languageCode: source,
                languages: languages,
                systemImage: "mic.fill",
                borderColor: .blue.opacity(0.3),
                onTap: onTapSource
            )
            
            // Swap Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    onSwap()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Swap languages")
            
            // Target Language Card
            LanguageCard(
                label: NSLocalizedString("translate_to", comment: "Target language label"),
                languageCode: target,
                languages: languages,
                systemImage: "speaker.wave.2.fill",
                borderColor: .green.opacity(0.3),
                onTap: onTapTarget
            )
        }
    }
}

struct LanguageCard: View {
    let label: String
    let languageCode: String
    let languages: [Language]
    let systemImage: String
    let borderColor: Color
    let onTap: () -> Void
    
    var currentLanguage: Language? {
        languages.first { $0.code == languageCode }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: systemImage)
                    .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 18))
                    .foregroundColor(.secondary)
                    .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 20 : 24)
                
                // Language Info
                VStack(alignment: .leading, spacing: UIDevice.current.userInterfaceIdiom == .pad ? 1 : 2) {
                    Text(label.uppercased())
                        .font(UIDevice.current.userInterfaceIdiom == .pad ? .caption2 : .caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        if let language = currentLanguage {
                            Text(language.flag)
                                .font(UIDevice.current.userInterfaceIdiom == .pad ? .title3 : .title2)
                            
                            Text(NSLocalizedString("language_\(languageCode)", comment: "Language name"))
                                .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 16 : 18, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, UIDevice.current.userInterfaceIdiom == .pad ? 10 : 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(currentLanguage?.name ?? languageCode)")
        .accessibilityHint("Tap to change language")
    }
}

// Preview
struct LanguageCardsSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LanguageCardsSelector(
                source: .constant("en"),
                target: .constant("es"),
                languages: Language.defaultLanguages,
                onSwap: {},
                onTapSource: {},
                onTapTarget: {}
            )
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}