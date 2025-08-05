import SwiftUI

struct SwapButton: View {
    let action: () -> Void
    @State private var isRotating = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isRotating.toggle()
            }
            action()
        }) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 44, height: 44)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .rotationEffect(.degrees(isRotating ? 180 : 0))
        .buttonStyle(PlainButtonStyle())
        .pressGesture {
            HapticManager.shared.mediumImpact()
        }
        .accessibilityLabel("Swap languages")
        .accessibilityHint("Double tap to swap source and target languages")
    }
}

#Preview {
    SwapButton {
        print("Swap languages")
    }
    .padding()
}