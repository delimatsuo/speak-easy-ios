import SwiftUI

struct SecondaryButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.selectionChanged()
        }) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? .accentColor : .secondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .scaleEffect(isActive ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

#Preview {
    HStack(spacing: 20) {
        SecondaryButton(icon: "keyboard", isActive: false) {
            print("Keyboard tapped")
        }
        
        SecondaryButton(icon: "keyboard", isActive: true) {
            print("Keyboard tapped (active)")
        }
        
        SecondaryButton(icon: "play.fill", isActive: false) {
            print("Play tapped")
        }
    }
    .padding()
}