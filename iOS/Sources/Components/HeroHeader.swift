import SwiftUI
import FirebaseAuth

// A modern, centered hero header with adaptive brand gradient.
// Two styles:
//  - fullBleed: fills width, square top & bottom edges (Apple-like large header)
//  - card: inset rounded-rectangle with all corners rounded
enum HeroHeaderStyle { case fullBleed, card }

struct HeroHeader: View {
    let title: String
    let subtitle: String?
    let onHistory: (() -> Void)?
    let onProfile: (() -> Void)?
    var style: HeroHeaderStyle = .fullBleed
    var remainingSeconds: Int? = nil
    
    // Adaptive height based on device type and orientation
    private var adaptiveHeight: CGFloat {
        #if os(iOS)
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let baseHeight: CGFloat = style == .fullBleed ? (isIPad ? 160 : 180) : (isIPad ? 120 : 140)
        return baseHeight
        #else
        return style == .fullBleed ? 180 : 140
        #endif
    }
    
    private var isIPadDevice: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            switch style {
            case .fullBleed:
                ZStack(alignment: .bottom) {
                    // Extend gradient slightly beyond safe area for a seamless top blend
                    Color.speakEasyPrimaryGradient
                        .ignoresSafeArea(edges: .top)

                    headerContent
                        .padding(.top, isIPadDevice ? 16 : 20)
                        .padding(.bottom, isIPadDevice ? 12 : 16)
                }
            case .card:
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.speakEasyPrimaryGradient)
                        .applyShadow(DesignConstants.Shadows.subtle)
                    headerContent
                        .padding(.vertical, isIPadDevice ? 12 : 14)
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: adaptiveHeight)
        .accessibilityElement(children: .combine)
    }

    private var headerContent: some View {
        VStack(spacing: isIPadDevice ? 6 : 8) {
            HStack(spacing: 12) {
                Spacer()
                if let onProfile = onProfile {
                    Button(action: onProfile) { ProfileBadgeView() }
                        .accessibilityLabel("Profile")
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: isIPadDevice ? 2 : 3) {
                Text(title)
                    .font(.system(size: isIPadDevice ? 26 : 30, weight: .bold))
                    .foregroundColor(.speakEasyOnPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: isIPadDevice ? 13 : 14, weight: .regular))
                        .foregroundColor(.speakEasyOnPrimarySecondary)
                        .tracking(0.5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if let seconds = remainingSeconds {
                    Text("\(format(seconds: seconds)) remaining")
                        .font(.system(size: isIPadDevice ? 13 : 14, weight: .semibold))
                        .foregroundColor(.speakEasyOnPrimary)
                        .padding(.top, isIPadDevice ? 2 : 3)
                    progressLine(seconds: seconds)
                        .frame(height: isIPadDevice ? 6 : 7)
                        .padding(.horizontal, isIPadDevice ? 40 : 32)
                        .padding(.top, 1)
                }
            }
            .padding(.horizontal, isIPadDevice ? 20 : 22)
        }
        .frame(maxWidth: .infinity)
    }
}

// Simple initial-based profile badge (placeholder until real photo)
private struct ProfileBadgeView: View {
    @State private var userInitials: String = ""
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.speakEasyOnPrimary.opacity(0.2))
                .frame(width: 36, height: 36)
            
            if !userInitials.isEmpty {
                Text(userInitials)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.speakEasyOnPrimary)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.speakEasyOnPrimary)
            }
        }
        .onAppear {
            loadUserInitials()
        }
    }
    
    private func loadUserInitials() {
        guard let user = Auth.auth().currentUser else { 
            print("🔍 [ProfileBadge] No current user")
            return 
        }
        
        // Debug: Print all available user data
        print("🔍 [ProfileBadge] User data available:")
        print("  • Display Name: \(user.displayName ?? "nil")")
        print("  • Email: \(user.email ?? "nil")")
        print("  • Photo URL: \(user.photoURL?.absoluteString ?? "nil")")
        print("  • Provider Data: \(user.providerData.map { "\($0.providerID): \($0.displayName ?? "no name")" })")
        
        // Try to get initials from display name
        if let displayName = user.displayName, !displayName.isEmpty {
            let components = displayName.components(separatedBy: " ")
            let initials = components.compactMap { $0.first }.prefix(2)
            userInitials = String(initials).uppercased()
            print("🔍 [ProfileBadge] Using display name initials: \(userInitials)")
        }
        // Fallback to email initial
        else if let email = user.email, !email.isEmpty {
            userInitials = String(email.prefix(1)).uppercased()
            print("🔍 [ProfileBadge] Using email initial: \(userInitials)")
        }
        else {
            print("🔍 [ProfileBadge] No display name or email available")
        }
    }
}

private extension HeroHeader {
    func progressLine(seconds: Int) -> some View {
        let maxSeconds = 1800.0
        let p = min(max(0.0, Double(seconds) / maxSeconds), 1.0)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(Color.white).frame(width: geo.size.width * p).opacity(0.9)
            }
        }
    }

    func format(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// RoundedCorners helper (bottom corners only)
private struct RoundedCorners: Shape {
    var radius: CGFloat = 16
    var corners: UIRectCorner = [.allCorners]

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#if DEBUG
struct HeroHeader_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 0) {
                HeroHeader(title: "Mervyn Talks", subtitle: "Speak to translate instantly", onHistory: {}, onProfile: {}, style: .card)
                Spacer()
            }
            .previewDisplayName("Light - Card")

            VStack(spacing: 0) {
                HeroHeader(title: "Mervyn Talks", subtitle: "Speak to translate instantly", onHistory: {}, onProfile: {}, style: .fullBleed)
                Spacer()
            }
            .previewDisplayName("Light - FullBleed")

            VStack(spacing: 0) {
                HeroHeader(title: "Mervyn Talks", subtitle: "Speak to translate instantly", onHistory: {}, onProfile: {}, style: .card)
                Spacer()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark - Card")
        }
    }
}
#endif


