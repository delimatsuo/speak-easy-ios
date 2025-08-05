import SwiftUI

struct TranslationProgressView: View {
    let state: RecordingState
    let progress: Double
    @State private var animateGradient = false
    
    var body: some View {
        VStack(spacing: 12) {
            progressIndicator
            progressText
        }
        .frame(height: 80)
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        switch state {
        case .recording:
            recordingIndicator
        case .processing:
            processingIndicator
        case .playback:
            playbackIndicator
        default:
            EmptyView()
        }
    }
    
    private var recordingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: 4, height: animateGradient ? 20 : 8)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: animateGradient
                    )
            }
        }
        .onAppear {
            animateGradient = true
        }
        .onDisappear {
            animateGradient = false
        }
    }
    
    private var processingIndicator: some View {
        VStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(1.2)
            
            // Network activity indicator
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .scaleEffect(animateGradient ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: animateGradient
                        )
                }
            }
        }
        .onAppear {
            animateGradient = true
        }
        .onDisappear {
            animateGradient = false
        }
    }
    
    private var playbackIndicator: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.green)
                    .frame(width: 3, height: animateGradient ? 16 : 6)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: animateGradient
                    )
            }
        }
        .onAppear {
            animateGradient = true
        }
        .onDisappear {
            animateGradient = false
        }
    }
    
    @ViewBuilder
    private var progressText: some View {
        switch state {
        case .recording:
            Text("Listening...")
                .font(.caption)
                .foregroundColor(.secondary)
                .transition(.opacity)
        case .processing:
            Text("Translating...")
                .font(.caption)
                .foregroundColor(.secondary)
                .transition(.opacity)
        case .playback:
            Text("Playing translation")
                .font(.caption)
                .foregroundColor(.secondary)
                .transition(.opacity)
        default:
            EmptyView()
        }
    }
}

struct NetworkActivityIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 4, height: 4)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ConfidenceIndicator: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform")
                .font(.caption2)
                .foregroundColor(confidenceColor)
            
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
                .foregroundColor(confidenceColor)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(confidenceColor.opacity(0.1))
        )
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.9...1.0:
            return .green
        case 0.7..<0.9:
            return .orange
        default:
            return .red
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        TranslationProgressView(state: .recording, progress: 0.3)
        TranslationProgressView(state: .processing, progress: 0.6)
        TranslationProgressView(state: .playback, progress: 0.8)
        
        HStack {
            ConfidenceIndicator(confidence: 0.95)
            ConfidenceIndicator(confidence: 0.75)
            ConfidenceIndicator(confidence: 0.45)
        }
        
        NetworkActivityIndicator()
    }
    .padding()
}