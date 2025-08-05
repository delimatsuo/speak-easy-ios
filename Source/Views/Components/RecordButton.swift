import SwiftUI

struct RecordButton: View {
    let state: RecordingState
    let onTapGesture: () -> Void
    
    @State private var isPulsing = false
    
    private var buttonSize: CGFloat {
        switch state {
        case .recording:
            return 100
        default:
            return 88
        }
    }
    
    private var buttonColor: LinearGradient {
        switch state {
        case .idle:
            return LinearGradient(
                colors: [Color(red: 0, green: 0.48, blue: 1), Color(red: 0, green: 0.32, blue: 0.84)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .recording:
            return LinearGradient(
                colors: [Color.red, Color(red: 0.8, green: 0, blue: 0)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .processing:
            return LinearGradient(
                colors: [Color.gray, Color(red: 0.6, green: 0.6, blue: 0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .playback:
            return LinearGradient(
                colors: [Color.green, Color(red: 0, green: 0.6, blue: 0)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .error:
            return LinearGradient(
                colors: [Color.red.opacity(0.7), Color.red.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var buttonIcon: String {
        switch state {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "ellipsis"
        case .playback:
            return "speaker.wave.2.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var isDisabled: Bool {
        switch state {
        case .processing:
            return true
        default:
            return false
        }
    }
    
    private var accessibilityLabel: String {
        switch state {
        case .idle:
            return "Record button"
        case .recording:
            return "Stop recording button"
        case .processing:
            return "Processing"
        case .playback:
            return "Playing translation"
        case .error:
            return "Error occurred"
        }
    }
    
    private var accessibilityHint: String {
        switch state {
        case .idle:
            return "Double tap to start recording"
        case .recording:
            return "Double tap to stop recording"
        case .processing:
            return "Please wait while processing"
        case .playback:
            return "Translation is playing"
        case .error:
            return "Double tap to try again"
        }
    }
    
    private var accessibilityValue: String {
        switch state {
        case .idle:
            return "Ready to record"
        case .recording:
            return "Recording in progress"
        case .processing:
            return "Processing audio"
        case .playback:
            return "Playing audio"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var body: some View {
        Button(action: {
            guard !isDisabled else { return }
            onTapGesture()
        }) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: buttonSize, height: buttonSize)
                
                if case .processing = state {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: buttonIcon)
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
        }
        .scaleEffect(isPulsing && state == .recording ? 1.1 : 1.0)
        .opacity(isDisabled ? 0.4 : 1.0)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: DeviceOptimization.shared.optimizedAnimationDuration(base: 0.2)), value: buttonSize)
        .animation(.easeInOut(duration: DeviceOptimization.shared.optimizedAnimationDuration(base: 0.2)), value: isDisabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(accessibilityValue)
        .onAppear {
            if case .recording = state {
                startPulsing()
            }
        }
        .onChange(of: state) { newState in
            if case .recording = newState {
                startPulsing()
            } else {
                stopPulsing()
            }
        }
        .pressGesture {
            switch state {
            case .idle:
                HapticManager.shared.heavyImpact()
            case .recording:
                HapticManager.shared.mediumImpact()
            default:
                HapticManager.shared.lightImpact()
            }
        }
    }
    
    private func startPulsing() {
        guard !DeviceOptimization.shared.shouldUseReducedAnimations() else {
            isPulsing = false
            return
        }
        
        let duration = DeviceOptimization.shared.optimizedAnimationDuration(base: 0.6)
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
    
    private func stopPulsing() {
        let duration = DeviceOptimization.shared.optimizedAnimationDuration(base: 0.2)
        withAnimation(.easeInOut(duration: duration)) {
            isPulsing = false
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        RecordButton(state: .idle) {
            print("Record tapped")
        }
        
        RecordButton(state: .recording) {
            print("Stop tapped")
        }
        
        RecordButton(state: .processing) {
            print("Processing...")
        }
        
        RecordButton(state: .playback) {
            print("Playing...")
        }
        
        RecordButton(state: .error("Test error")) {
            print("Error state")
        }
    }
    .padding()
}