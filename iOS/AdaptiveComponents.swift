//
//  AdaptiveComponents.swift
//  Mervyn Talks
//
//  Modern, responsive UI components that adapt to device size and user preferences
//  Built with iOS 17 design principles and accessibility in mind
//

import SwiftUI

// MARK: - Adaptive Microphone Button

struct AdaptiveMicrophoneButton: View {
    @Binding var isRecording: Bool
    let isProcessing: Bool
    let isPlaying: Bool
    let action: () -> Void
    
    @State private var pulseAnimation = false
    @State private var pressAnimation = false
    
    private let responsive = ResponsiveDesign()
    
    var body: some View {
        GeometryReader { geometry in
            let buttonSize = responsive.buttonSize(baseSize: min(geometry.size.width, geometry.size.height) * 0.8)
            let pulseSize = responsive.pulseSize(forButtonSize: buttonSize)
            
            ZStack {
                // Pulse animation rings (only when recording)
                if isRecording {
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(Color.speakEasyRecording.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                            .frame(width: pulseSize + CGFloat(index * 20), height: pulseSize + CGFloat(index * 20))
                            .scaleEffect(pulseAnimation ? 1.2 + CGFloat(index) * 0.1 : 1.0)
                            .opacity(pulseAnimation ? 0.0 : 0.6)
                            .animation(
                                Animation.easeOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(index) * 0.2),
                                value: pulseAnimation
                            )
                    }
                }
                
                // Main button
                Button(action: {
                    HapticFeedback.medium()
                    withAnimation(ModernAnimations.snappy) {
                        pressAnimation.toggle()
                    }
                    action()
                }) {
                    ZStack {
                        // Background gradient
                        Circle()
                            .fill(isRecording ? 
                                  LinearGradient(gradient: Gradient(colors: [Color.speakEasyRecording, Color.speakEasyRecording.opacity(0.8)]), startPoint: .top, endPoint: .bottom) :
                                  Color.speakEasyPrimaryGradient)
                            .frame(width: buttonSize, height: buttonSize)
                        
                        // Shadow
                        Circle()
                            .fill(Color.black.opacity(0.1))
                            .frame(width: buttonSize, height: buttonSize)
                            .blur(radius: 8)
                            .offset(y: 4)
                        
                        // Icon
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: responsive.fontSize(for: .microphone), weight: .medium))
                            .foregroundColor(.white)
                            .scaleEffect(pressAnimation ? 0.9 : 1.0)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isProcessing || isPlaying)
                .scaleEffect(isRecording ? 1.05 : 1.0)
                .scaleEffect(pressAnimation ? 0.95 : 1.0)
                .opacity((isProcessing || isPlaying) ? 0.6 : 1.0)
                .animation(ModernAnimations.gentle, value: isRecording)
                .animation(ModernAnimations.snappy, value: pressAnimation)
                .accessibleMicrophoneButton(
                    isRecording: isRecording,
                    isProcessing: isProcessing,
                    isPlaying: isPlaying
                )
                .onAppear {
                    if isRecording {
                        pulseAnimation = true
                    }
                }
                .onChange(of: isRecording) { newValue in
                    pulseAnimation = newValue
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Adaptive Language Picker

struct AdaptiveLanguagePicker: View {
    @Binding var selectedLanguage: String
    let languages: [Language]
    let isSource: Bool
    let title: String
    
    private let responsive = ResponsiveDesign()
    
    var body: some View {
        VStack(spacing: responsive.spacing(for: .small)) {
            Text(title)
                .font(DynamicTypeSupport.font(for: .caption, weight: .medium))
                .foregroundColor(.speakEasyTextSecondary)
                .accessibleHeading(.h3)
            
            Menu {
                ForEach(languages) { language in
                    Button(action: {
                        HapticFeedback.selection()
                        withAnimation(ModernAnimations.gentle) {
                            selectedLanguage = language.code
                        }
                    }) {
                        Label(language.name, systemImage: "flag")
                    }
                }
            } label: {
                HStack(spacing: responsive.spacing(for: .small)) {
                    if let selectedLang = languages.first(where: { $0.code == selectedLanguage }) {
                        Text(selectedLang.flag)
                            .font(.title2)
                        
                        Text(selectedLang.name)
                            .font(DynamicTypeSupport.font(for: .subheadline, weight: .medium))
                            .foregroundColor(.speakEasyTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.speakEasyTextSecondary)
                }
                .padding(.horizontal, responsive.spacing(for: .medium))
                .padding(.vertical, responsive.spacing(for: .small) + 2)
                .background(
                    RoundedRectangle(cornerRadius: responsive.cornerRadius(for: .medium))
                        .fill(Color.speakEasyPickerBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
            }
            .accessibleLanguagePicker(
                isSource: isSource,
                selectedLanguage: languages.first(where: { $0.code == selectedLanguage })?.name ?? "Unknown"
            )
        }
    }
}

// MARK: - Adaptive Swap Languages Button

struct AdaptiveSwapButton: View {
    let sourceLanguage: String
    let targetLanguage: String
    let action: () -> Void
    
    @State private var rotationAngle = 0.0
    
    private let responsive = ResponsiveDesign()
    private var isDisabled: Bool { sourceLanguage == targetLanguage }
    
    var body: some View {
        VStack(spacing: responsive.spacing(for: .extraSmall)) {
            Button(action: {
                HapticFeedback.light()
                withAnimation(ModernAnimations.springRotation) {
                    rotationAngle += 180
                }
                action()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.speakEasyPrimary.opacity(isDisabled ? 0.05 : 0.15))
                        .frame(width: responsive.buttonSize(baseSize: 44), 
                               height: responsive.buttonSize(baseSize: 44))
                    
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: responsive.fontSize(for: .headline), weight: .medium))
                        .foregroundColor(isDisabled ? .speakEasyTextSecondary.opacity(0.5) : .speakEasyPrimary)
                        .rotationEffect(.degrees(rotationAngle))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isDisabled)
            .springPressEffect(pressedScale: 0.9)
            .accessibleSwapButton(isDisabled: isDisabled)
            
            Text("\(languageCode(sourceLanguage))→\(languageCode(targetLanguage))")
                .font(DynamicTypeSupport.font(for: .caption2))
                .foregroundColor(.speakEasyTextSecondary)
                .opacity(isDisabled ? 0.5 : 1.0)
        }
    }
    
    private func languageCode(_ fullCode: String) -> String {
        return fullCode.uppercased()
    }
}

// MARK: - Adaptive Text Display Card

struct AdaptiveTextDisplayCard: View {
    let title: String
    let text: String
    let icon: String
    let backgroundColor: Color
    let showReplayButton: Bool
    let onReplay: (() -> Void)?
    
    private let responsive = ResponsiveDesign()
    
    var body: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(for: .small)) {
            // Header
            Label(title, systemImage: icon)
                .font(DynamicTypeSupport.font(for: .caption, weight: .medium))
                .foregroundColor(.speakEasyTextSecondary)
                .accessibleHeading(.h3)
            
            // Text content
            ScrollView {
                Text(text)
                    .font(DynamicTypeSupport.font(for: .body))
                    .foregroundColor(.speakEasyTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 50, maxHeight: 120)
            
            // Replay button if needed
            if showReplayButton, let replayAction = onReplay {
                Button(action: {
                    HapticFeedback.light()
                    replayAction()
                }) {
                    Label("Replay", systemImage: "play.circle")
                        .font(DynamicTypeSupport.font(for: .caption, weight: .medium))
                        .foregroundColor(.speakEasyPrimary)
                }
                .accessibilityLabel(AccessibilityConfig.Labels.replayButton)
                .accessibilityHint(AccessibilityConfig.Labels.replayButtonHint)
            }
        }
        .padding(responsive.spacing(for: .medium))
        .frame(maxWidth: responsive.cardWidth())
        .background(
            RoundedRectangle(cornerRadius: responsive.cornerRadius(for: .large))
                .fill(backgroundColor)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .accessibleCard(title: title, content: text)
        .scaleInTransition()
    }
}

// MARK: - Adaptive Status Indicator

struct AdaptiveStatusIndicator: View {
    enum Status {
        case recording(duration: Int)
        case processing(elapsed: Double?)
        case playing
        case idle
        
        var title: String {
            switch self {
            case .recording: return "Listening..."
            case .processing: return "Translating..."
            case .playing: return "Playing translation..."
            case .idle: return "Tap to speak"
            }
        }
        
        var color: Color {
            switch self {
            case .recording: return .speakEasyRecording
            case .processing: return .speakEasyProcessing
            case .playing: return .speakEasyPrimary
            case .idle: return .speakEasyTextSecondary
            }
        }
    }
    
    let status: Status
    let onCancel: (() -> Void)?
    
    @State private var waveOffsets: [CGFloat] = Array(repeating: 0, count: 15)
    
    private let responsive = ResponsiveDesign()
    
    var body: some View {
        VStack(spacing: responsive.spacing(for: .medium)) {
            statusContent
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
        }
        .animation(ModernAnimations.gentle, value: status.title)
    }
    
    @ViewBuilder
    private var statusContent: some View {
        switch status {
        case .recording(let duration):
            recordingView(duration: duration)
        case .processing(let elapsed):
            processingView(elapsed: elapsed)
        case .playing:
            playingView
        case .idle:
            idleView
        }
    }
    
    private func recordingView(duration: Int) -> some View {
        VStack(spacing: responsive.spacing(for: .small)) {
            Text(status.title)
                .font(DynamicTypeSupport.font(for: .headline, weight: .semibold))
                .foregroundColor(status.color)
            
            Text(formatDuration(duration))
                .font(DynamicTypeSupport.font(for: .caption))
                .foregroundColor(.speakEasyTextSecondary)
            
            // Animated waveform
            HStack(spacing: 2) {
                ForEach(0..<waveOffsets.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(status.color)
                        .frame(width: 3, height: 8 + waveOffsets[index])
                        .animation(
                            ModernAnimations.wave(delay: Double(index) * 0.05),
                            value: waveOffsets[index]
                        )
                }
            }
            .frame(height: 30)
            .onAppear { startWaveAnimation() }
        }
    }
    
    private func processingView(elapsed: Double?) -> some View {
        VStack(spacing: responsive.spacing(for: .small)) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: status.color))
                .scaleEffect(1.2)
            
            Text(status.title)
                .font(DynamicTypeSupport.font(for: .headline, weight: .semibold))
                .foregroundColor(status.color)
            
            if let elapsed = elapsed {
                Text("Elapsed: \(String(format: "%.0f", elapsed))s / 30s max")
                    .font(DynamicTypeSupport.font(for: .caption))
                    .foregroundColor(.speakEasyTextSecondary)
            } else {
                Text("This may take up to 30 seconds")
                    .font(DynamicTypeSupport.font(for: .caption))
                    .foregroundColor(.speakEasyTextSecondary)
            }
            
            if let cancelAction = onCancel {
                Button("Cancel Translation", action: {
                    HapticFeedback.warning()
                    cancelAction()
                })
                .font(DynamicTypeSupport.font(for: .caption, weight: .medium))
                .foregroundColor(.red)
                .padding(.top, responsive.spacing(for: .small))
                .accessibilityLabel(AccessibilityConfig.Labels.cancelButton)
                .accessibilityHint(AccessibilityConfig.Labels.cancelButtonHint)
            }
        }
    }
    
    private var playingView: some View {
        VStack(spacing: responsive.spacing(for: .small)) {
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: responsive.fontSize(for: .title)))
                .foregroundColor(status.color)
                .pulseEffect(isActive: true, scale: 1.1)
            
            Text(status.title)
                .font(DynamicTypeSupport.font(for: .headline, weight: .semibold))
                .foregroundColor(status.color)
        }
    }
    
    private var idleView: some View {
        Text(status.title)
            .font(DynamicTypeSupport.font(for: .headline))
            .foregroundColor(status.color)
            .breathingEffect(scale: 1.02)
    }
    
    private func startWaveAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard case .recording = status else { return }
            
            for i in waveOffsets.indices {
                waveOffsets[i] = CGFloat.random(in: 5...20)
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Adaptive Usage Statistics Card

struct AdaptiveUsageStatsCard: View {
    @StateObject private var usageService = UsageTrackingService.shared
    @State private var showingDetails = false
    
    private let responsive = ResponsiveDesign()
    
    var body: some View {
        HStack(spacing: responsive.spacing(for: .medium)) {
            // Beta badge or usage info
            if usageService.isUnlimitedBeta {
                betaBadge
            } else {
                usageInfo
            }
            
            Spacer()
            
            // Action buttons
            actionButtons
        }
        .padding(responsive.spacing(for: .medium))
        .background(cardBackground)
        .sheet(isPresented: $showingDetails) {
            UsageDetailView()
        }
    }
    
    private var betaBadge: some View {
        HStack(spacing: responsive.spacing(for: .small)) {
            Text("BETA")
                .font(DynamicTypeSupport.font(for: .caption2, weight: .bold))
                .padding(.horizontal, responsive.spacing(for: .small))
                .padding(.vertical, 2)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
            
            Text("Unlimited minutes during beta")
                .font(DynamicTypeSupport.font(for: .footnote))
                .foregroundColor(.speakEasyTextSecondary)
        }
        .accessibleStatistic(label: "Beta status", value: "Unlimited minutes")
    }
    
    private var usageInfo: some View {
        VStack(alignment: .leading, spacing: responsive.spacing(for: .extraSmall)) {
            Text("\(String(format: "%.1f", usageService.minutesRemainingForDisplay)) min remaining")
                .font(DynamicTypeSupport.font(for: .footnote, weight: .medium))
                .accessibleStatistic(
                    label: "Minutes remaining", 
                    value: String(format: "%.1f", usageService.minutesRemainingForDisplay)
                )
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.speakEasyTextSecondary.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(usageWarningColor)
                        .frame(width: geometry.size.width * usageService.minutesUsedPercentage(), height: 4)
                        .animation(ModernAnimations.gentle, value: usageService.minutesUsedPercentage())
                }
            }
            .frame(height: 4)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: responsive.spacing(for: .small)) {
            if !usageService.isUnlimitedBeta && usageService.shouldShowLowMinutesWarning() {
                Button("Add Minutes") {
                    HapticFeedback.selection()
                    showingDetails = true
                }
                .font(DynamicTypeSupport.font(for: .footnote, weight: .medium))
                .padding(.horizontal, responsive.spacing(for: .small))
                .padding(.vertical, 4)
                .background(Color.speakEasyPrimary)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .springPressEffect()
            }
            
            Button(action: { 
                HapticFeedback.selection()
                showingDetails = true 
            }) {
                Image(systemName: "chart.bar")
                    .font(.system(size: responsive.fontSize(for: .body)))
                    .foregroundColor(.speakEasyPrimary)
            }
            .accessibilityLabel(AccessibilityConfig.Labels.usageStatsButton)
            .accessibilityHint(AccessibilityConfig.Labels.usageStatsButtonHint)
            .accessibleTouchTarget()
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: responsive.cornerRadius(for: .medium))
            .fill(Color.speakEasySecondaryBackground)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    private var usageWarningColor: Color {
        if usageService.minutesRemainingForDisplay > 10 {
            return .speakEasyPrimary
        } else if usageService.minutesRemainingForDisplay > 5 {
            return .orange
        } else {
            return .speakEasyRecording
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct AdaptiveComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 30) {
                AdaptiveMicrophoneButton(
                    isRecording: .constant(false),
                    isProcessing: false,
                    isPlaying: false,
                    action: {}
                )
                .frame(height: 200)
                
                HStack {
                    AdaptiveLanguagePicker(
                        selectedLanguage: .constant("en"),
                        languages: Language.defaultLanguages,
                        isSource: true,
                        title: "Speak in"
                    )
                    
                    AdaptiveSwapButton(
                        sourceLanguage: "en",
                        targetLanguage: "es",
                        action: {}
                    )
                    
                    AdaptiveLanguagePicker(
                        selectedLanguage: .constant("es"),
                        languages: Language.defaultLanguages,
                        isSource: false,
                        title: "Translate to"
                    )
                }
                
                AdaptiveStatusIndicator(
                    status: .recording(duration: 15),
                    onCancel: {}
                )
                
                AdaptiveTextDisplayCard(
                    title: "You said:",
                    text: "Hello, how are you today?",
                    icon: "mic",
                    backgroundColor: .speakEasyTranscribedBackground,
                    showReplayButton: false,
                    onReplay: nil
                )
                
                AdaptiveUsageStatsCard()
            }
            .padding()
        }
    }
}
#endif