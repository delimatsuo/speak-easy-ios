import SwiftUI

struct TextDisplayCard: View {
    let text: String
    let language: Language
    let placeholder: String
    let isTranslation: Bool
    let onCopy: (() -> Void)?
    
    private var accessibilityLabel: String {
        isTranslation ? "\(language.name) translation" : "\(language.name) transcription"
    }
    
    private var accessibilityValue: String {
        if text.isEmpty {
            return placeholder
        } else {
            return text
        }
    }
    
    private var accessibilityHint: String {
        if text.isEmpty {
            return isTranslation ? "Translation will appear here when available" : "Spoken text will appear here"
        } else {
            return "Swipe up or down for more options"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language.flag)
                    .font(.caption)
                
                Text(language.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !text.isEmpty {
                    Menu {
                        Button("Copy") {
                            UIPasteboard.general.string = text
                            HapticManager.shared.lightImpact()
                            onCopy?()
                        }
                        
                        if isTranslation {
                            Button("Share") {
                                // TODO: Implement share functionality
                            }
                            
                            Button("Play Audio") {
                                // TODO: Implement audio playback
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if text.isEmpty {
                        Text(placeholder)
                            .foregroundColor(.secondary)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(text)
                            .foregroundColor(.primary)
                            .font(isTranslation ? .body.weight(.semibold) : .body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .background(
            isTranslation 
                ? Color.accentColor.opacity(0.1)
                : Color(.secondarySystemBackground)
        )
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: text)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
    }
}

#Preview {
    VStack(spacing: 16) {
        TextDisplayCard(
            text: "Hello, how are you today?",
            language: Language.defaultSource,
            placeholder: "Tap to start speaking...",
            isTranslation: false,
            onCopy: { print("Copied!") }
        )
        
        TextDisplayCard(
            text: "¡Hola! ¿Cómo estás hoy?",
            language: Language.defaultTarget,
            placeholder: "Translation will appear here...",
            isTranslation: true,
            onCopy: { print("Copied!") }
        )
        
        TextDisplayCard(
            text: "",
            language: Language.defaultTarget,
            placeholder: "Translation will appear here...",
            isTranslation: true,
            onCopy: nil
        )
    }
    .padding()
}