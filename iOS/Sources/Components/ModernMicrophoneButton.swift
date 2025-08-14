//
//  ModernMicrophoneButton.swift
//  Mervyn Talks
//
//  Professional microphone button with proper proportions (130pt - not oversized!)
//

import SwiftUI

struct ModernMicrophoneButton: View {
    @Binding var isRecording: Bool
    let isProcessing: Bool
    let isPlaying: Bool
    let action: () -> Void
    
    @State private var pulseAnimation = false
    @State private var pressScale: CGFloat = 1.0
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Pulse Rings (only when recording)
            if isRecording {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(
                            DesignConstants.Colors.recording.opacity(0.3 - Double(index) * 0.1),
                            lineWidth: 2
                        )
                        .frame(
                            width: DesignConstants.Sizing.microphoneButtonSize + CGFloat(index * 30),
                            height: DesignConstants.Sizing.microphoneButtonSize + CGFloat(index * 30)
                        )
                        .scaleEffect(pulseAnimation ? 1.3 + CGFloat(index) * 0.1 : 1.0)
                        .opacity(pulseAnimation ? 0.0 : 0.6)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                            value: pulseAnimation
                        )
                }
            }
            
            // Main Button
            Button(action: handleButtonPress) {
                ZStack {
                    // Button Background with Gradient + soft halo
                    ZStack {
                        Circle()
                            .fill(buttonGradient)
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        Circle()
                            .fill(Color.black.opacity(0.06))
                            .blur(radius: 20)
                            .scaleEffect(1.12)
                            .opacity(0.6)
                    }
                    .frame(
                        width: DesignConstants.Sizing.microphoneButtonSize,
                        height: DesignConstants.Sizing.microphoneButtonSize
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 18, y: 8)
                    
                    // Button Icon
                    Image(systemName: buttonIcon)
                        .font(.system(
                            size: DesignConstants.Sizing.microphoneIconSize,
                            weight: .medium,
                            design: .rounded
                        ))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(rotation))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDisabled)
            .scaleEffect(pressScale)
            .opacity(isDisabled ? 0.6 : 1.0)
            .animation(DesignConstants.Animations.bounce, value: pressScale)
            .animation(DesignConstants.Animations.gentle, value: isRecording)
            .animation(DesignConstants.Animations.gentle, value: isProcessing)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(isDisabled ? [] : .isButton)
        }
        .onAppear {
            if isRecording {
                startPulseAnimation()
            }
        }
        .onChange(of: isRecording) { newValue in
            if newValue {
                startPulseAnimation()
            } else {
                stopPulseAnimation()
            }
        }
        .onChange(of: isProcessing) { newValue in
            if newValue {
                startProcessingAnimation()
            } else {
                stopProcessingAnimation()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonGradient: LinearGradient {
        if isRecording {
            return DesignConstants.Colors.microphoneRecording
        } else {
            return DesignConstants.Colors.microphoneDefault
        }
    }
    
    private var buttonIcon: String {
        if isRecording {
            return "stop.fill"
        } else if isProcessing {
            return "waveform"
        } else if isPlaying {
            return "speaker.wave.2.fill"
        } else {
            return "mic.fill"
        }
    }
    
    private var isDisabled: Bool {
        return isProcessing || isPlaying
    }
    
    private var accessibilityLabel: String {
        if isRecording {
            return "Stop recording"
        } else if isProcessing {
            return "Processing translation"
        } else if isPlaying {
            return "Playing translation"
        } else {
            return "Start recording"
        }
    }
    
    private var accessibilityHint: String {
        if isDisabled {
            return "Button is disabled while processing"
        } else if isRecording {
            return "Tap to stop recording your voice"
        } else {
            return "Tap to start recording your voice for translation"
        }
    }
    
    // MARK: - Actions
    
    private func handleButtonPress() {
        // Haptic Feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Visual Feedback
        withAnimation(DesignConstants.Animations.quick) {
            pressScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(DesignConstants.Animations.bounce) {
                pressScale = 1.0
            }
        }
        
        // Execute Action
        action()
    }
    
    // MARK: - Animations
    
    private func startPulseAnimation() {
        withAnimation(DesignConstants.Animations.pulse) {
            pulseAnimation = true
        }
    }
    
    private func stopPulseAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseAnimation = false
        }
    }
    
    private func startProcessingAnimation() {
        withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
    }
    
    private func stopProcessingAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            rotation = 0
        }
    }
}

// MARK: - Modern Status Indicator

struct ModernStatusIndicator: View {
    let status: StatusType
    let onCancel: (() -> Void)?
    
    enum StatusType {
        case idle
        case recording(duration: Int)
        case processing(elapsed: Double?)
        case playing
        
        var title: String {
            switch self {
            case .idle:
                return "Tap the button to speak"
            case .recording:
                return "Listening..."
            case .processing:
                return "Translating..."
            case .playing:
                return "Playing translation..."
            }
        }
        
        var color: Color {
            switch self {
            case .idle:
                return DesignConstants.Colors.secondaryText
            case .recording:
                return DesignConstants.Colors.recording
            case .processing:
                return DesignConstants.Colors.processing
            case .playing:
                return DesignConstants.Colors.primary
            }
        }
    }
    
    var body: some View {
        VStack(spacing: DesignConstants.Layout.smallSpacing) {
            statusContent
        }
        .frame(minHeight: DesignConstants.Sizing.statusIndicatorHeight)
        .animation(DesignConstants.Animations.gentle, value: status.title)
    }
    
    @ViewBuilder
    private var statusContent: some View {
        switch status {
        case .idle:
            idleView
        case .recording(let duration):
            recordingView(duration: duration)
        case .processing(let elapsed):
            processingView(elapsed: elapsed)
        case .playing:
            playingView
        }
    }
    
    private var idleView: some View {
        Text(status.title)
            .font(.system(size: DesignConstants.Typography.statusSubtitleSize, 
                        weight: DesignConstants.Typography.statusSubtitleWeight))
            .foregroundColor(status.color)
            .multilineTextAlignment(.center)
    }
    
    private func recordingView(duration: Int) -> some View {
        VStack(spacing: DesignConstants.Layout.smallSpacing) {
            Text(status.title)
                .font(.system(size: DesignConstants.Typography.statusTitleSize, 
                            weight: DesignConstants.Typography.statusTitleWeight))
                .foregroundColor(status.color)
            
            Text(formatDuration(duration))
                .font(.system(size: DesignConstants.Typography.statusSubtitleSize, 
                            weight: DesignConstants.Typography.statusSubtitleWeight))
                .foregroundColor(DesignConstants.Colors.secondaryText)
            
            // Simple waveform visualization
            WaveformView()
        }
    }
    
    private func processingView(elapsed: Double?) -> some View {
        VStack(spacing: DesignConstants.Layout.elementSpacing) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: status.color))
                .scaleEffect(1.2)
            
            Text(status.title)
                .font(.system(size: DesignConstants.Typography.statusTitleSize, 
                            weight: DesignConstants.Typography.statusTitleWeight))
                .foregroundColor(status.color)
            
            if let elapsed = elapsed {
                Text("Elapsed: \(String(format: "%.0f", elapsed))s")
                    .font(.system(size: DesignConstants.Typography.statusSubtitleSize))
                    .foregroundColor(DesignConstants.Colors.secondaryText)
            }
            
            if let cancelAction = onCancel {
                Button("Cancel", action: cancelAction)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
    }
    
    private var playingView: some View {
        VStack(spacing: DesignConstants.Layout.smallSpacing) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title2)
                .foregroundColor(status.color)
            
            Text(status.title)
                .font(.system(size: DesignConstants.Typography.statusTitleSize, 
                            weight: DesignConstants.Typography.statusTitleWeight))
                .foregroundColor(status.color)
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Simple Waveform View

struct WaveformView: View {
    @State private var animatingBars = Array(repeating: false, count: 5)
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(DesignConstants.Colors.recording)
                    .frame(width: 3)
                    .frame(height: animatingBars[index] ? 20 : 8)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: animatingBars[index]
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            for index in animatingBars.indices {
                animatingBars[index] = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ModernMicrophoneButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Idle State
            ModernMicrophoneButton(
                isRecording: .constant(false),
                isProcessing: false,
                isPlaying: false,
                action: {}
            )
            
            // Recording State
            ModernMicrophoneButton(
                isRecording: .constant(true),
                isProcessing: false,
                isPlaying: false,
                action: {}
            )
            
            // Status Indicators
            ModernStatusIndicator(
                status: .recording(duration: 15),
                onCancel: {}
            )
            
            ModernStatusIndicator(
                status: .processing(elapsed: 5.2),
                onCancel: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif