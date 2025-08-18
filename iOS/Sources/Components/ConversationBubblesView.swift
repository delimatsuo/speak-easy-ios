import SwiftUI

struct ConversationBubblesView: View {
    let sourceText: String
    let targetText: String
    let onPlay: () -> Void
    let onShare: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if !sourceText.isEmpty {
                HStack {
                    bubble(text: sourceText, isTarget: false)
                    Spacer(minLength: 20)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            if !targetText.isEmpty {
                HStack {
                    Spacer(minLength: 20)
                    bubble(text: targetText, isTarget: true) {
                        HStack(spacing: 8) {
                            Button(action: onPlay) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.white)
                                    .padding(6)
                            }
                            
                            Button(action: onShare) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                                    .padding(6)
                            }
                        }
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
    }
    
    @ViewBuilder
    private func bubble(text: String, isTarget: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(isTarget ? .white : .speakEasyTextPrimary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isTarget ? Color.speakEasyPrimaryGradient : LinearGradient(gradient: Gradient(colors: [Color(.secondarySystemBackground), Color(.secondarySystemBackground)]), startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: .leading)
    }

    @ViewBuilder
    private func bubble<Trailing: View>(text: String, isTarget: Bool, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(isTarget ? .white : .speakEasyTextPrimary)
                .multilineTextAlignment(.leading)
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isTarget ? Color.speakEasyPrimaryGradient : LinearGradient(gradient: Gradient(colors: [Color(.secondarySystemBackground), Color(.secondarySystemBackground)]), startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: .leading)
    }
}


