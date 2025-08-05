import SwiftUI

struct WaveformView: View {
    let audioLevel: Double
    
    @State private var animationValues: [Double] = Array(repeating: 0.1, count: 20)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<animationValues.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: 3)
                    .frame(height: max(4, animationValues[index] * 60))
                    .animation(
                        .easeInOut(duration: 0.1 + Double(index) * 0.05)
                        .repeatForever(autoreverses: true),
                        value: animationValues[index]
                    )
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            updateWaveform()
        }
    }
    
    private func updateWaveform() {
        for index in 0..<animationValues.count {
            let baseLevel = audioLevel * 0.5
            let randomVariation = Double.random(in: 0.1...1.0)
            let distanceFromCenter = abs(index - animationValues.count / 2)
            let centerBoost = 1.0 - (Double(distanceFromCenter) / Double(animationValues.count / 2)) * 0.5
            
            animationValues[index] = baseLevel * randomVariation * centerBoost + 0.1
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        WaveformView(audioLevel: 0.3)
            .frame(height: 60)
        
        WaveformView(audioLevel: 0.7)
            .frame(height: 60)
        
        WaveformView(audioLevel: 1.0)
            .frame(height: 60)
    }
    .padding()
}