import SwiftUI

struct LanguageButton: View {
    let language: Language
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack {
                    Text(language.flag)
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(language.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("(\(label))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if language.isOfflineAvailable {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 160, height: 60)
        .background(Color(.systemBackground).opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor, lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .buttonStyle(PlainButtonStyle())
        .pressGesture {
            HapticManager.shared.selectionChanged()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(language.name) language button")
        .accessibilityHint("Double tap to change \(label.lowercased()) language")
        .accessibilityValue("Currently selected: \(language.name)")
    }
}

#Preview {
    VStack(spacing: 20) {
        LanguageButton(
            language: Language.defaultSource,
            label: "Source"
        ) {}
        
        LanguageButton(
            language: Language.defaultTarget,
            label: "Target"
        ) {}
    }
    .padding()
}