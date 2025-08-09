import SwiftUI

struct LanguageChipsRow: View {
    @Binding var source: String
    @Binding var target: String
    let languages: [Language]
    let onSwap: () -> Void
    let onTapSource: () -> Void
    let onTapTarget: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            chip(languageCode: source, title: Language.name(for: source), isSource: true)
                .onTapGesture { onTapSource() }
            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white, Color.speakEasyPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.speakEasyPrimary.opacity(0.12)))
            }
            chip(languageCode: target, title: Language.name(for: target), isSource: false)
                .onTapGesture { onTapTarget() }
        }
    }
    
    private func chip(languageCode: String, title: String, isSource: Bool) -> some View {
        HStack(spacing: 10) {
            Text(emoji(for: languageCode))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.06)))
    }
    
    private func emoji(for code: String) -> String { Language.defaultLanguages.first { $0.code == code }?.flag ?? "🌐" }
}


