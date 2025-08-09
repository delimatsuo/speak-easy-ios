import SwiftUI

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

    var body: some View {
        Group {
            switch style {
            case .fullBleed:
                ZStack(alignment: .bottom) {
                    Color.speakEasyPrimaryGradient
                        .ignoresSafeArea(edges: .top)

                    headerContent
                        .padding(.top, 24)
                        .padding(.bottom, 20)
                }
            case .card:
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.speakEasyPrimaryGradient)
                        .applyShadow(DesignConstants.Shadows.subtle)
                    headerContent
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(height: style == .fullBleed ? 220 : 160)
        .accessibilityElement(children: .combine)
    }

    private var headerContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Spacer()
                if let onProfile = onProfile {
                    Button(action: onProfile) { ProfileBadgeView() }
                        .accessibilityLabel("Profile")
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.speakEasyOnPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.speakEasyOnPrimarySecondary)
                        .tracking(0.5)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if let seconds = remainingSeconds {
                    Text("\(format(seconds: seconds)) remaining")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.speakEasyOnPrimary)
                        .padding(.top, 4)
                    progressLine(seconds: seconds)
                        .frame(height: 8)
                        .padding(.horizontal, 32)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
    }
}

// Simple initial-based profile badge (placeholder until real photo)
private struct ProfileBadgeView: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.22)).frame(width: 28, height: 28)
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.speakEasyOnPrimary)
        }
        .accessibilityHidden(true)
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


