import SwiftUI

struct SpeakEasyIcon: View {
    /// Total icon size (e.g. 1024 for App Store, 180 for home-screen preview, etc.)
    var size: CGFloat = 1024

    var body: some View {
        ZStack {
            // Background with blue→green gradient
            RoundedRectangle(cornerRadius: size * 0.2)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.00, green: 0.60, blue: 0.40),
                            Color(red: 0.00, green: 0.40, blue: 0.75)
                        ]),
                        startPoint: .bottomTrailing,
                        endPoint: .topLeading
                    )
                )
                .frame(width: size, height: size)

            // Face silhouette at left, 30% of width
            FaceSilhouette()
                .fill(Color.white)
                .frame(width: size * 0.30, height: size * 0.80)
                .offset(x: -size * 0.20)

            // Three sound-wave arcs at right
            SoundWaves(lineWidth: size * 0.04, count: 3)
                .stroke(Color.white, lineWidth: size * 0.04)
                .frame(width: size * 0.50, height: size * 0.80)
                .offset(x: size * 0.10)
        }
        .frame(width: size, height: size)
    }
}

// MARK: – Face Silhouette Shape
struct FaceSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height

        // Start at forehead
        p.move(to: CGPoint(x: w * 0.95, y: h * 0.15))
        // Curve down over the nose to the chin
        p.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.50),
            control1: CGPoint(x: w * 0.90, y: h * 0.00),
            control2: CGPoint(x: w * 0.20, y: h * 0.35)
        )
        // Curve back up from chin to the back of the skull
        p.addCurve(
            to: CGPoint(x: w * 0.95, y: h * 0.85),
            control1: CGPoint(x: w * 0.00, y: h * 0.65),
            control2: CGPoint(x: w * 0.90, y: h * 1.10)
        )
        // Close the shape
        p.addLine(to: CGPoint(x: w * 0.95, y: h * 0.15))
        return p
    }
}

// MARK: – Sound-Wave Arcs Shape
struct SoundWaves: Shape {
    let lineWidth: CGFloat
    let count: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let centerY = rect.midY
        let startX = rect.minX + lineWidth / 2

        // Draw `count` concentric arcs from smallest to largest
        for i in 0..<count {
            let radius = (CGFloat(i + 1) / CGFloat(count)) * (rect.width / 2 - lineWidth)
            p.addArc(
                center: CGPoint(x: startX, y: centerY),
                radius: radius,
                startAngle: Angle(degrees: -45),
                endAngle: Angle(degrees: 45),
                clockwise: false
            )
        }
        return p
    }
}

// MARK: – Preview
struct SpeakEasyIcon_Previews: PreviewProvider {
    static var previews: some View {
        SpeakEasyIcon(size: 180)  // Home-screen preview
            .previewLayout(.sizeThatFits)
            .padding()
    }
}