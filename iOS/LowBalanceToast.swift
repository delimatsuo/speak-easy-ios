import SwiftUI

struct LowBalanceToast: View {
    let remainingSeconds: Int
    let onBuy: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Low balance")
                    .font(.subheadline.weight(.semibold))
                Text("\(format(seconds: remainingSeconds)) remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Top up", action: onBuy)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    private func format(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}


