#!/usr/bin/env swift

import SwiftUI
import AppKit

// Include the icon code
struct SpeakEasyIcon: View {
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

struct FaceSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height

        p.move(to: CGPoint(x: w * 0.95, y: h * 0.15))
        p.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.50),
            control1: CGPoint(x: w * 0.90, y: h * 0.00),
            control2: CGPoint(x: w * 0.20, y: h * 0.35)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.95, y: h * 0.85),
            control1: CGPoint(x: w * 0.00, y: h * 0.65),
            control2: CGPoint(x: w * 0.90, y: h * 1.10)
        )
        p.addLine(to: CGPoint(x: w * 0.95, y: h * 0.15))
        return p
    }
}

struct SoundWaves: Shape {
    let lineWidth: CGFloat
    let count: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let centerY = rect.midY
        let startX = rect.minX + lineWidth / 2

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

// Icon sizes to generate
let iconSizes = [
    ("AppIcon-20@1x", 20),
    ("AppIcon-20@2x", 40),
    ("AppIcon-20@3x", 60),
    ("AppIcon-29@1x", 29),
    ("AppIcon-29@2x", 58),
    ("AppIcon-29@3x", 87),
    ("AppIcon-40@1x", 40),
    ("AppIcon-40@2x", 80),
    ("AppIcon-40@3x", 120),
    ("AppIcon-60@2x", 120),
    ("AppIcon-60@3x", 180),
    ("AppIcon-76@1x", 76),
    ("AppIcon-76@2x", 152),
    ("AppIcon-83.5@2x", 167),
    ("AppIcon-1024@1x", 1024)
]

// Function to render and save icon
func generateIcon(name: String, size: Int) {
    let icon = SpeakEasyIcon(size: CGFloat(size))
    
    // Create NSView to host SwiftUI view
    let hostingView = NSHostingView(rootView: icon)
    hostingView.frame = CGRect(x: 0, y: 0, width: size, height: size)
    
    // Create bitmap representation
    let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    
    // Draw the view into the bitmap
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
    hostingView.layer?.render(in: NSGraphicsContext.current!.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    
    // Save as PNG
    if let data = bitmapRep.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: "./\(name).png")
        try? data.write(to: url)
        print("Generated \(name).png (\(size)x\(size))")
    }
}

// Generate all icons
print("Generating Speak Easy app icons...")
for (name, size) in iconSizes {
    generateIcon(name: name, size: size)
}
print("Done! All icons generated.")