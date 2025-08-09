import SwiftUI

struct LanguageChipsRow: View {
    @Binding var source: String
    @Binding var target: String
    let languages: [Language]
    let onSwap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            chip(languageCode: source, title: "English", isSource: true)
                .onTapGesture { }
            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white, Color.speakEasyPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.speakEasyPrimary.opacity(0.12)))
            }
            chip(languageCode: target, title: "Spanish", isSource: false)
                .onTapGesture { }
        }
    }
    
    private func chip(languageCode: String, title: String, isSource: Bool) -> some View {
        HStack(spacing: 10) {
            Text(emoji(for: languageCode))
            Text(Language.name(for: languageCode))
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


