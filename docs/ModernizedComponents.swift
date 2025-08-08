//
//  ModernizedComponents.swift
//  Mervyn Talks - Updated Components with Modern Design
//
//  Completely redesigned components using semantic colors
//  and modern SwiftUI patterns for proper dark/light mode support
//

import SwiftUI
import AVFoundation

// MARK: - Modern Text Display Card (Replaces existing TextDisplayCard)
struct ModernTextDisplayCard: View {
    let text: String
    let language: Language
    let placeholder: String
    let isTranslation: Bool
    let onCopy: (() -> Void)?
    let onShare: (() -> Void)?
    let onReplay: (() -> Void)?
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showCopySuccess = false
    @State private var isExpanded = false
    
    private var accessibilityLabel: String {
        let typeLabel = isTranslation ? "translation" : "transcription"
        return "\(language.name) \(typeLabel)"
    }
    
    private var accessibilityValue: String {
        text.isEmpty ? placeholder : text
    }
    
    private var accessibilityHint: String {
        if text.isEmpty {
            return isTranslation ? 
                "Translation will appear here when available" : 
                "Your spoken text will appear here"
        } else {
            return "Double tap to expand, swipe up for more options"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            // Header with language info and actions
            headerSection
            
            // Text content area
            textContentSection
        }
        .padding(AppSpacing.medium)
        .background(cardBackground)
        .cornerRadius(AppCornerRadius.card)
        .shadow(
            color: shadowColor,
            radius: 4,
            x: 0,
            y: 2
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.card)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .animation(.easeInOut(duration: 0.2), value: text)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .accessibilityAction(named: "Copy") { onCopy?() }
        .accessibilityAction(named: "Share") { onShare?() }
        .accessibilityAction(named: "Replay") { onReplay?() }
        .alert("Copied!", isPresented: $showCopySuccess) {
            Button("OK") { }
        }
    }
    
    private var headerSection: some View {
        HStack {
            // Language indicator
            HStack(spacing: AppSpacing.xxSmall) {
                Text(language.flag)
                    .font(.appCaption)
                    .accessibilityHidden(true)
                
                Text(language.name)
                    .font(.appCaption)
                    .foregroundColor(.speakEasyTextSecondary)
                
                // Translation indicator
                if isTranslation {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundColor(.speakEasyTextTertiary)
                        .accessibilityHidden(true)
                    
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption2)
                        .foregroundColor(.speakEasyPrimary)
                        .accessibilityHidden(true)
                }
            }
            
            Spacer()
            
            // Action buttons
            if !text.isEmpty {
                actionButtons
            }
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: AppSpacing.xSmall) {
            // Copy button
            if let onCopy = onCopy {
                Button(action: {
                    onCopy()
                    showCopySuccess = true
                    HapticManager.shared.lightImpact()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(.speakEasyPrimary)
                }
                .accessibilityLabel("Copy text")
                .accessibilityHint("Copy this text to clipboard")
            }
            
            // Share button
            if let onShare = onShare {
                Button(action: {
                    onShare()
                    HapticManager.shared.lightImpact()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.speakEasyPrimary)
                }
                .accessibilityLabel("Share text")
                .accessibilityHint("Share this text with other apps")
            }
            
            // Replay button (for translations)
            if isTranslation, let onReplay = onReplay {
                Button(action: {
                    onReplay()
                    HapticManager.shared.lightImpact()
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.caption)
                        .foregroundColor(.speakEasySuccess)
                }
                .accessibilityLabel("Replay audio")
                .accessibilityHint("Play the audio for this translation")
            }
            
            // Expand/collapse button for long text
            if text.count > 100 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.speakEasyTextSecondary)
                }
                .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
                .accessibilityHint(isExpanded ? "Show less text" : "Show full text")
            }
        }
    }
    
    private var textContentSection: some View {
        Group {
            if text.isEmpty {
                // Placeholder text
                Text(placeholder)
                    .font(.appBody)
                    .foregroundColor(.speakEasyTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44) // Ensure minimum tap target
                    .multilineTextAlignment(.leading)
            } else {
                // Actual text content
                ScrollView {
                    Text(text)
                        .font(isTranslation ? .appBodyEmphasized : .appBody)
                        .foregroundColor(.speakEasyTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.leading)
                        .lineLimit(isExpanded ? nil : 6)
                }
                .frame(maxHeight: isExpanded ? .infinity : 120)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var cardBackground: Color {
        if isTranslation {
            return Color.speakEasyTranslatedBackground
        } else {
            return Color.speakEasyTranscribedBackground
        }
    }
    
    private var borderColor: Color {
        if isTranslation {
            return Color.speakEasyPrimary.opacity(0.2)
        } else {
            return Color.speakEasySeparator.opacity(0.3)
        }
    }
    
    private var borderWidth: CGFloat {
        isTranslation ? 1 : 0.5
    }
    
    private var shadowColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.3)
        default:
            return Color.black.opacity(0.1)
        }
    }
}

// MARK: - Modern Record Button (Replaces existing RecordButton)
struct ModernRecordButton: View {
    let state: RecordingState
    let onTapGesture: () -> Void
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isPulsing = false
    @State private var rotationAngle: Double = 0
    @FocusState private var isFocused: Bool
    
    // Adaptive sizing based on device
    private var buttonSize: CGFloat {
        switch DeviceSize.current {
        case .compact:
            return state == .recording ? 140 : 130
        case .regular:
            return state == .recording ? 160 : 150
        case .large, .extraLarge:
            return state == .recording ? 180 : 170
        }
    }
    
    private var iconSize: CGFloat {
        buttonSize * 0.35
    }
    
    var body: some View {
        ZStack {
            // Pulse animation background (only when recording and motion not reduced)
            if state == .recording && !reduceMotion {
                Circle()
                    .fill(Color.speakEasyRecording.opacity(0.2))
                    .frame(width: buttonSize + 60, height: buttonSize + 60)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            }
            
            // Main button
            Button(action: {
                guard !isDisabled else { return }
                onTapGesture()
                provideHapticFeedback()
            }) {
                ZStack {
                    // Button background with gradient
                    Circle()
                        .fill(buttonGradient)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(
                            color: shadowColor,
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    isFocused ? Color.white.opacity(0.8) : Color.clear,
                                    lineWidth: 3
                                )
                        )
                    
                    // Button content (icon or loading indicator)
                    Group {
                        if state == .processing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: buttonIcon)
                                .font(.system(size: iconSize, weight: .medium))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(rotationAngle))
                        }
                    }
                }
            }
            .disabled(isDisabled)
            .scaleEffect(buttonScale)
            .opacity(isDisabled && state != .processing ? 0.6 : 1.0)
            .buttonStyle(PlainButtonStyle())
            .focused($isFocused)
        }
        .frame(width: buttonSize + 80, height: buttonSize + 80) // Larger tap area
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isDisabled ? [.isButton, .notEnabled] : [.isButton])
        .onChange(of: state) { newState in
            handleStateChange(newState)
        }
        .onAppear {
            if state == .recording && !reduceMotion {
                isPulsing = true
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonScale)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }
    
    // MARK: - Computed Properties
    
    private var buttonGradient: LinearGradient {
        switch state {
        case .idle:
            return Color.speakEasyPrimaryGradient
        case .recording:
            return LinearGradient(
                colors: [Color.speakEasyRecording, Color.speakEasyRecording.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .processing:
            return LinearGradient(
                colors: [Color.speakEasyProcessing, Color.speakEasyProcessing.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .playback:
            return LinearGradient(
                colors: [Color.speakEasySuccess, Color.speakEasySuccess.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .error:
            return LinearGradient(
                colors: [Color.speakEasyError.opacity(0.7), Color.speakEasyError.opacity(0.5)],
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
            return "speaker.wave.3.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var isDisabled: Bool {
        state == .processing
    }
    
    private var buttonScale: CGFloat {
        if isFocused {
            return 1.05
        } else if state == .recording {
            return 1.02
        } else {
            return 1.0
        }
    }
    
    private var shadowColor: Color {
        Color.black.opacity(0.2)
    }
    
    private var accessibilityLabel: String {
        switch state {
        case .idle:
            return "Record button"
        case .recording:
            return "Stop recording"
        case .processing:
            return "Processing translation"
        case .playback:
            return "Playing translation"
        case .error:
            return "Error occurred"
        }
    }
    
    private var accessibilityHint: String {
        switch state {
        case .idle:
            return "Double tap to start recording your voice for translation"
        case .recording:
            return "Double tap to stop recording"
        case .processing:
            return "Translation is being processed, please wait"
        case .playback:
            return "Audio is currently playing"
        case .error:
            return "An error occurred, double tap to try again"
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
    
    // MARK: - Helper Methods
    
    private func handleStateChange(_ newState: RecordingState) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if newState == .recording && !reduceMotion {
                isPulsing = true
            } else {
                isPulsing = false
            }
        }
        
        // Add rotation animation for processing state
        if newState == .processing && !reduceMotion {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        } else {
            withAnimation(.easeOut(duration: 0.3)) {
                rotationAngle = 0
            }
        }
    }
    
    private func provideHapticFeedback() {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        
        switch state {
        case .idle:
            style = .heavy
        case .recording:
            style = .medium
        case .error:
            style = .heavy
        default:
            style = .light
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Modern Language Picker (Replaces existing LanguagePicker)
struct ModernLanguagePicker: View {
    @Binding var selectedLanguage: String
    let languages: [Language]
    let title: String
    let icon: String
    
    @State private var isExpanded = false
    @Environment(\.colorScheme) var colorScheme
    
    var selectedLanguageObject: Language? {
        languages.first { $0.code == selectedLanguage }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            // Title with icon
            Label(title, systemImage: icon)
                .font(.appCaption.weight(.medium))
                .foregroundColor(.speakEasyTextSecondary)
                .accessibilityHidden(true)
            
            // Language picker menu
            Menu {
                ForEach(languages) { language in
                    Button(action: {
                        selectedLanguage = language.code
                        announceLanguageSelection(language.name)
                    }) {
                        HStack {
                            Text(language.flag)
                                .font(.body)
                            Text(language.name)
                                .font(.body)
                            
                            Spacer()
                            
                            if selectedLanguage == language.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.speakEasySuccess)
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    // Current selection
                    if let selected = selectedLanguageObject {
                        Text(selected.flag)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.name)
                                .font(.appBody.weight(.medium))
                                .foregroundColor(.speakEasyTextPrimary)
                                .lineLimit(1)
                            
                            Text(selected.code.uppercased())
                                .font(.appCaption2)
                                .foregroundColor(.speakEasyTextTertiary)
                        }
                    } else {
                        Text("Select Language")
                            .font(.appBody)
                            .foregroundColor(.speakEasyTextSecondary)
                    }
                    
                    Spacer()
                    
                    // Dropdown indicator
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.speakEasyTextTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.small)
                .frame(minHeight: 44) // Accessibility minimum
                .background(pickerBackground)
                .cornerRadius(AppCornerRadius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                        .stroke(borderColor, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) language picker")
        .accessibilityValue(selectedLanguageObject?.name ?? "No language selected")
        .accessibilityHint("Double tap to select a different language")
    }
    
    private var pickerBackground: Color {
        switch colorScheme {
        case .dark:
            return Color.speakEasyTertiaryBackground
        default:
            return Color.speakEasySecondaryBackground
        }
    }
    
    private var borderColor: Color {
        Color.speakEasySeparator.opacity(0.5)
    }
    
    private func announceLanguageSelection(_ languageName: String) {
        // Announce to VoiceOver users
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Selected \(languageName)"
            )
        }
    }
}

// MARK: - Modern Usage Statistics View
struct ModernUsageStatsView: View {
    @StateObject private var usageService = UsageTrackingService.shared
    @State private var showingDetails = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            // Beta badge or usage info
            if usageService.isUnlimitedBeta {
                betaBadge
            } else {
                usageInfo
            }
            
            Spacer()
            
            // Stats button
            Button(action: { showingDetails = true }) {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(.speakEasyPrimary)
            }
            .accessibilityLabel("View usage statistics")
            .accessibilityHint("Double tap to see detailed usage information")
        }
        .padding(AppSpacing.medium)
        .background(cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingDetails) {
            ModernUsageDetailsView()
        }
    }
    
    private var betaBadge: some View {
        HStack(spacing: AppSpacing.small) {
            // Beta indicator
            HStack(spacing: AppSpacing.xxSmall) {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundColor(.white)
                
                Text("BETA")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, AppSpacing.xSmall)
            .padding(.vertical, AppSpacing.xxxSmall)
            .background(Color.speakEasyPrimary)
            .cornerRadius(AppCornerRadius.small)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Unlimited Translation")
                    .font(.appCaption.weight(.medium))
                    .foregroundColor(.speakEasyTextPrimary)
                
                Text("Beta access expires when app launches")
                    .font(.caption2)
                    .foregroundColor(.speakEasyTextSecondary)
                    .lineLimit(2)
            }
        }
    }
    
    private var usageInfo: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            HStack {
                Text("\(String(format: "%.1f", usageService.minutesRemainingForDisplay)) minutes left")
                    .font(.appCallout.weight(.medium))
                    .foregroundColor(.speakEasyTextPrimary)
                
                Spacer()
                
                if usageService.shouldShowLowMinutesWarning() {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.speakEasyWarning)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.speakEasyTertiaryBackground)
                        .frame(height: 4)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 2)
                        .fill(usageProgressColor)
                        .frame(
                            width: geometry.size.width * usageService.minutesUsedPercentage(),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
        }
    }
    
    private var usageProgressColor: Color {
        if usageService.minutesRemainingForDisplay > 10 {
            return Color.speakEasySuccess
        } else if usageService.minutesRemainingForDisplay > 5 {
            return Color.speakEasyWarning
        } else {
            return Color.speakEasyError
        }
    }
    
    private var cardBackground: Color {
        Color.speakEasySecondaryBackground
    }
    
    private var shadowColor: Color {
        switch colorScheme {
        case .dark:
            return Color.black.opacity(0.3)
        default:
            return Color.black.opacity(0.1)
        }
    }
}

// MARK: - Placeholder for Usage Details View
struct ModernUsageDetailsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Usage Details")
                    .font(.appTitle)
                    .padding()
                
                Text("Modern usage statistics view would be implemented here")
                    .font(.appBody)
                    .foregroundColor(.speakEasyTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Usage Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.speakEasyPrimary)
                }
            }
        }
    }
}

// MARK: - Modern Sound Wave Visualization
struct ModernSoundWaveView: View {
    @Binding var isAnimating: Bool
    let barCount: Int
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    init(isAnimating: Binding<Bool>, barCount: Int = 15) {
        self._isAnimating = isAnimating
        self.barCount = barCount
    }
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.speakEasyRecording)
                    .frame(width: 3)
                    .frame(height: barHeight(for: index))
                    .animation(
                        animationForBar(at: index),
                        value: isAnimating
                    )
            }
        }
        .accessibilityHidden(true) // Purely decorative
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        if reduceMotion || !isAnimating {
            return 12 // Static height when motion is reduced or not animating
        }
        return CGFloat.random(in: 8...28)
    }
    
    private func animationForBar(at index: Int) -> Animation? {
        if reduceMotion {
            return .none
        }
        
        return isAnimating ?
            .easeInOut(duration: 0.4)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.05) :
            .easeOut(duration: 0.2)
    }
}

#Preview {
    VStack(spacing: 30) {
        ModernTextDisplayCard(
            text: "Hello, how are you today?",
            language: Language.defaultSource,
            placeholder: "Tap to start speaking...",
            isTranslation: false,
            onCopy: { print("Copied!") }
        )
        
        ModernTextDisplayCard(
            text: "¡Hola! ¿Cómo estás hoy?",
            language: Language.defaultTarget,
            placeholder: "Translation will appear here...",
            isTranslation: true,
            onCopy: { print("Copied!") },
            onReplay: { print("Replaying...") }
        )
        
        ModernRecordButton(state: .idle) {
            print("Record tapped")
        }
        
        ModernUsageStatsView()
    }
    .padding()
    .background(Color.speakEasyBackground)
}