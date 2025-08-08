//
//  ModernContentView.swift
//  Mervyn Talks - Modernized Main Interface
//
//  Completely redesigned with proper dark/light mode support,
//  modern SwiftUI patterns, and responsive design
//

import SwiftUI
import AVFoundation
import Speech

struct ModernContentView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var translationService = TranslationService.shared
    @StateObject private var usageService = UsageTrackingService.shared
    
    // MARK: - State Management
    @State private var sourceLanguage = "en"
    @State private var targetLanguage = "es"
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var isPlaying = false
    @State private var transcribedText = ""
    @State private var translatedText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var availableLanguages: [Language] = []
    @State private var showHistory = false
    @State private var recordingDuration = 0
    @State private var showConnectionTest = false
    @State private var isTestingConnection = false
    @State private var processingStartTime: Date?
    @State private var translationTask: Task<Void, Never>?
    
    // MARK: - UI State
    @State private var pulseAnimation = false
    @State private var soundWaveAnimation = false
    @State private var swapRotation = 0.0
    @State private var recordingTimer: Timer?
    @State private var processingTimer: Timer?
    
    // MARK: - Environment
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // FIXED: Adaptive background that works in both light and dark mode
                    Color.appBackground
                        .ignoresSafeArea()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppSpacing.sectionSpacing) {
                            // Usage Statistics
                            ModernUsageStatisticsView()
                                .responsivePadding()
                            
                            // Language Selection
                            modernLanguageSelection
                                .responsivePadding()
                            
                            // Recording Interface
                            modernRecordingInterface
                                .responsiveSectionSpacing()
                            
                            // Text Display Areas
                            if !transcribedText.isEmpty || !translatedText.isEmpty {
                                modernTextDisplays
                                    .responsivePadding()
                                    .transition(.opacity.combined(with: .scale))
                            }
                            
                            Spacer(minLength: AppSpacing.xxxLarge)
                        }
                    }
                }
            }
            .navigationTitle("Mervyn Talks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.appPrimary)
                    }
                    .appAccessibility(label: "View translation history")
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showConnectionTest = true }) {
                        Image(systemName: isTestingConnection ? "wifi.circle" : "wifi")
                            .foregroundColor(.appSecondary)
                    }
                    .disabled(isTestingConnection)
                    .appAccessibility(label: "Test connection")
                }
            }
            .sheet(isPresented: $showHistory) {
                ModernHistoryView()
            }
            .sheet(isPresented: $showConnectionTest) {
                ModernConnectionTestView()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    resetUIState()
                }
                if !errorMessage.contains("✅") {
                    Button("Retry") {
                        retryLastTranslation()
                    }
                }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                setupApp()
            }
            .onChange(of: isRecording) { newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    pulseAnimation = newValue
                    soundWaveAnimation = newValue
                }
            }
            .onChange(of: isProcessing) { newValue in
                if newValue {
                    processingStartTime = Date()
                    startProcessingTimer()
                } else {
                    processingStartTime = nil
                    stopProcessingTimer()
                }
            }
            .accessibilityResponsive()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Modern Language Selection
    private var modernLanguageSelection: some View {
        HStack(spacing: AppSpacing.medium) {
            // Source Language
            ModernLanguagePicker(
                selectedLanguage: $sourceLanguage,
                languages: availableLanguages,
                title: "Speak in",
                icon: "mic.fill"
            )
            
            // Swap Button
            VStack(spacing: AppSpacing.xxSmall) {
                Button(action: swapLanguages) {
                    ZStack {
                        Circle()
                            .fill(Color.appPrimary.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "arrow.2.circlepath")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.appPrimary)
                            .rotationEffect(.degrees(swapRotation))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(sourceLanguage == targetLanguage)
                .opacity(sourceLanguage == targetLanguage ? 0.3 : 1.0)
                .appAccessibility(
                    label: "Swap languages",
                    hint: "Swaps source and target languages for translation"
                )
                
                Text("\(languageCode(sourceLanguage)) → \(languageCode(targetLanguage))")
                    .font(.appCaption)
                    .foregroundColor(.appSecondaryText)
            }
            
            // Target Language
            ModernLanguagePicker(
                selectedLanguage: $targetLanguage,
                languages: availableLanguages,
                title: "Translate to",
                icon: "speaker.wave.2.fill"
            )
        }
        .appCardStyle()
        .responsivePadding()
    }
    
    // MARK: - Modern Recording Interface
    private var modernRecordingInterface: some View {
        VStack(spacing: AppSpacing.large) {
            // Recording Button with Modern Design
            ZStack {
                // Pulse animation background
                if isRecording {
                    Circle()
                        .fill(Color.appRecording.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }
                
                // Main Record Button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(recordButtonGradient)
                            .frame(width: recordButtonSize, height: recordButtonSize)
                            .shadow(
                                color: AppShadow.large.color,
                                radius: AppShadow.large.radius,
                                x: AppShadow.large.x,
                                y: AppShadow.large.y
                            )
                        
                        Image(systemName: recordButtonIcon)
                            .font(.system(size: recordButtonIconSize, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .disabled(isProcessing || isPlaying)
                .scaleEffect(isRecording ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
                .appAccessibility(
                    label: recordingAccessibilityLabel,
                    hint: recordingAccessibilityHint,
                    traits: .isButton
                )
            }
            
            // Status Display
            modernStatusDisplay
        }
    }
    
    // MARK: - Modern Text Displays
    private var modernTextDisplays: some View {
        VStack(spacing: AppSpacing.cardSpacing) {
            // Transcribed Text
            if !transcribedText.isEmpty {
                ModernTextCard(
                    text: transcribedText,
                    title: "You said:",
                    icon: "mic.fill",
                    language: sourceLanguage,
                    isOriginal: true
                )
            }
            
            // Translated Text
            if !translatedText.isEmpty {
                ModernTextCard(
                    text: translatedText,
                    title: "Translation:",
                    icon: "speaker.wave.2.fill",
                    language: targetLanguage,
                    isOriginal: false,
                    onReplay: replayTranslation
                )
            }
        }
    }
    
    // MARK: - Status Display
    @ViewBuilder
    private var modernStatusDisplay: some View {
        if isRecording {
            VStack(spacing: AppSpacing.small) {
                Text("Listening...")
                    .font(.appHeadline)
                    .foregroundColor(.appRecording)
                
                Text(formatDuration(recordingDuration))
                    .font(.appCaption)
                    .foregroundColor(.appSecondaryText)
                
                // Modern sound wave visualization
                ModernSoundWaveView(isAnimating: $soundWaveAnimation)
                    .frame(height: 40)
            }
            .transition(.opacity.combined(with: .scale))
            
        } else if isProcessing {
            VStack(spacing: AppSpacing.small) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .appProcessing))
                    .scaleEffect(1.5)
                
                Text("Translating...")
                    .font(.appHeadline)
                    .foregroundColor(.appProcessing)
                
                if let processingTime = processingStartTime {
                    let elapsed = Date().timeIntervalSince(processingTime)
                    Text("Elapsed: \(String(format: "%.0f", elapsed))s / 30s max")
                        .font(.appCaption)
                        .foregroundColor(.appSecondaryText)
                }
                
                Button("Cancel Translation") {
                    cancelTranslation()
                }
                .font(.appCaption)
                .foregroundColor(.appError)
                .padding(.top, AppSpacing.xSmall)
            }
            .transition(.opacity.combined(with: .scale))
            
        } else if isPlaying {
            VStack(spacing: AppSpacing.small) {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.title)
                    .foregroundColor(.appSuccess)
                
                Text("Playing translation...")
                    .font(.appHeadline)
                    .foregroundColor(.appSuccess)
            }
            .transition(.opacity.combined(with: .scale))
            
        } else {
            Text("Tap to speak")
                .font(.appHeadline)
                .foregroundColor(.appSecondaryText)
        }
    }
    
    // MARK: - Computed Properties
    
    private var recordButtonGradient: LinearGradient {
        if isRecording {
            return LinearGradient(
                colors: [Color.appRecording, Color.appRecording.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return Color.appPrimaryGradient
        }
    }
    
    private var recordButtonSize: CGFloat {
        switch DeviceSize.current {
        case .compact:
            return isRecording ? 140 : 130
        case .regular:
            return isRecording ? 160 : 150
        case .large, .extraLarge:
            return isRecording ? 180 : 170
        }
    }
    
    private var recordButtonIconSize: CGFloat {
        switch DeviceSize.current {
        case .compact:
            return 50
        case .regular:
            return 60
        case .large, .extraLarge:
            return 70
        }
    }
    
    private var recordButtonIcon: String {
        isRecording ? "stop.fill" : "mic.fill"
    }
    
    private var recordingAccessibilityLabel: String {
        isRecording ? "Stop recording" : "Start recording"
    }
    
    private var recordingAccessibilityHint: String {
        isRecording ? "Double tap to stop recording" : "Double tap to start recording your voice for translation"
    }
    
    // MARK: - Actions (Updated for Modern Patterns)
    
    private func setupApp() {
        setupAudio()
        loadLanguages()
        requestPermissions()
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: isRecording ? .heavy : .medium)
        impactFeedback.impactOccurred()
        
        // Track usage
        if isRecording {
            usageService.startTranslationSession()
        } else {
            usageService.endTranslationSession()
        }
    }
    
    private func swapLanguages() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Animate the swap icon
        withAnimation(.easeInOut(duration: 0.3)) {
            swapRotation += 180
        }
        
        // Swap the languages
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
    }
    
    // MARK: - Helper Methods (Keeping existing logic but with modern patterns)
    
    @MainActor
    private func startRecording() {
        transcribedText = ""
        translatedText = ""
        recordingDuration = 0
        
        Task {
            let success = await audioManager.startRecordingAsync()
            if success {
                isRecording = true
                startRecordingTimer()
            } else {
                errorMessage = "Failed to start recording. Please check microphone permissions."
                showError = true
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        stopRecordingTimer()
        
        audioManager.stopRecording { audioURL in
            if let audioURL = audioURL {
                processRecording(audioURL)
            } else {
                errorMessage = "Failed to save recording"
                showError = true
            }
        }
    }
    
    private func processRecording(_ audioURL: URL) {
        isProcessing = true
        processingStartTime = Date()
        
        translationTask = Task {
            do {
                // Speech to Text
                let transcription = try await audioManager.transcribeAudio(audioURL, language: sourceLanguage)
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.transcribedText = transcription
                }
                
                // Translation
                let response = try await translationService.translateWithAudio(
                    text: transcription,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.translatedText = response.translatedText
                }
                
                // Play audio if available
                if let audioData = response.audioData {
                    await MainActor.run {
                        self.isProcessing = false
                    }
                    playTranslation(audioData)
                } else {
                    await MainActor.run {
                        self.isProcessing = false
                    }
                }
                
            } catch is CancellationError {
                await MainActor.run {
                    self.isProcessing = false
                    self.processingStartTime = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = self.formatErrorMessage(error)
                    self.showError = true
                    self.isProcessing = false
                    self.processingStartTime = nil
                    self.usageService.cancelTranslationSession()
                }
            }
        }
    }
    
    private func cancelTranslation() {
        translationTask?.cancel()
        translationTask = nil
        translationService.cancelCurrentTranslation()
        
        isProcessing = false
        processingStartTime = nil
        usageService.cancelTranslationSession()
    }
    
    @MainActor
    private func playTranslation(_ audioData: Data) {
        isPlaying = true
        Task {
            let _ = await audioManager.playAudioAsync(audioData)
            isPlaying = false
        }
    }
    
    private func replayTranslation() {
        if let audioData = audioManager.lastAudioData {
            playTranslation(audioData)
        }
    }
    
    private func resetUIState() {
        isRecording = false
        isProcessing = false
        isPlaying = false
        processingStartTime = nil
        
        translationTask?.cancel()
        translationTask = nil
        
        stopRecordingTimer()
        stopProcessingTimer()
    }
    
    private func retryLastTranslation() {
        if !transcribedText.isEmpty {
            isProcessing = true
            processingStartTime = Date()
            
            translationTask = Task {
                do {
                    let response = try await translationService.translateWithAudio(
                        text: transcribedText,
                        from: sourceLanguage,
                        to: targetLanguage
                    )
                    
                    await MainActor.run {
                        self.translatedText = response.translatedText
                        self.isProcessing = false
                    }
                    
                    if let audioData = response.audioData {
                        playTranslation(audioData)
                    }
                } catch is CancellationError {
                    await MainActor.run {
                        self.isProcessing = false
                        self.processingStartTime = nil
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Retry failed: \(self.formatErrorMessage(error))"
                        self.showError = true
                        self.isProcessing = false
                        self.processingStartTime = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods (Keeping existing implementation)
    
    private func setupAudio() {
        audioManager.setupSession()
    }
    
    private func requestPermissions() {
        Task {
            await requestPermissionsAsync()
        }
    }
    
    @MainActor
    private func requestPermissionsAsync() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let granted = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                
                await MainActor.run {
                    if !granted {
                        self.errorMessage = "Microphone access is required for voice translation"
                        self.showError = true
                    }
                }
            }
            
            group.addTask {
                let status = await withCheckedContinuation { continuation in
                    SFSpeechRecognizer.requestAuthorization { status in
                        continuation.resume(returning: status)
                    }
                }
                
                await MainActor.run {
                    if status != .authorized {
                        self.errorMessage = "Speech recognition access is required"
                        self.showError = true
                    }
                }
            }
        }
    }
    
    private func loadLanguages() {
        Task {
            do {
                let languages = try await translationService.fetchSupportedLanguages()
                await MainActor.run {
                    self.availableLanguages = languages
                }
            } catch {
                await MainActor.run {
                    self.availableLanguages = Language.defaultLanguages
                }
            }
        }
    }
    
    private func formatErrorMessage(_ error: Error) -> String {
        if let translationError = error as? TranslationError {
            return translationError.localizedDescription
        }
        return "Translation failed: \(error.localizedDescription)"
    }
    
    // MARK: - Timer Methods
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            recordingDuration += 1
            if recordingDuration >= 60 {
                stopRecording()
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func startProcessingTimer() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let startTime = self.processingStartTime,
               Date().timeIntervalSince(startTime) > 35 {
                self.cancelTranslation()
            }
        }
    }
    
    private func stopProcessingTimer() {
        processingTimer?.invalidate()
        processingTimer = nil
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func languageCode(_ fullCode: String) -> String {
        return fullCode.uppercased()
    }
}

// MARK: - Modern Supporting Views

struct ModernLanguagePicker: View {
    @Binding var selectedLanguage: String
    let languages: [Language]
    let title: String
    let icon: String
    
    var body: some View {
        VStack(spacing: AppSpacing.xSmall) {
            Label(title, systemImage: icon)
                .font(.appCaption)
                .foregroundColor(.appSecondaryText)
            
            Picker("", selection: $selectedLanguage) {
                ForEach(languages) { language in
                    Text(language.flag + " " + language.name).tag(language.code)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(minWidth: 100)
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.xSmall)
            .background(Color.appTertiaryBackground)
            .cornerRadius(AppCornerRadius.small)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ModernTextCard: View {
    let text: String
    let title: String
    let icon: String
    let language: String
    let isOriginal: Bool
    let onReplay: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.appCaption)
                    .foregroundColor(.appSecondaryText)
                
                Spacer()
                
                if !isOriginal && onReplay != nil {
                    Button(action: { onReplay?() }) {
                        Label("Replay", systemImage: "play.circle.fill")
                            .font(.appCaption)
                            .foregroundColor(.appPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Text(text)
                .font(isOriginal ? .appBody : .appBodyEmphasized)
                .foregroundColor(.appPrimaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
        }
        .padding(AppSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card)
                .fill(isOriginal ? Color.appSecondaryBackground : Color.appPrimary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.card)
                .stroke(isOriginal ? Color.clear : Color.appPrimary.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ModernUsageStatisticsView: View {
    @StateObject private var usageService = UsageTrackingService.shared
    @State private var showingFullStats = false
    
    var body: some View {
        HStack(spacing: AppSpacing.small) {
            if usageService.isUnlimitedBeta {
                Label("BETA", systemImage: "crown.fill")
                    .font(.appCaption2.weight(.bold))
                    .padding(.horizontal, AppSpacing.xSmall)
                    .padding(.vertical, AppSpacing.xxxSmall)
                    .background(Color.appPrimary)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                
                Text("Unlimited minutes during beta")
                    .font(.appCaption)
                    .foregroundColor(.appSecondaryText)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xxxSmall) {
                    Text("\(String(format: "%.1f", usageService.minutesRemainingForDisplay)) min remaining")
                        .font(.appCaption.weight(.medium))
                        .foregroundColor(.appPrimaryText)
                    
                    ProgressView(value: usageService.minutesUsedPercentage())
                        .progressViewStyle(LinearProgressViewStyle(tint: usageWarningColor))
                        .frame(height: 4)
                }
            }
            
            Spacer()
            
            Button(action: { showingFullStats.toggle() }) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.appPrimary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppSpacing.small)
        .appCardStyle()
        .sheet(isPresented: $showingFullStats) {
            // ModernUsageDetailView() - would need to be created
        }
    }
    
    private var usageWarningColor: Color {
        if usageService.minutesRemainingForDisplay > 10 {
            return .appSuccess
        } else if usageService.minutesRemainingForDisplay > 5 {
            return .appWarning
        } else {
            return .appError
        }
    }
}

struct ModernSoundWaveView: View {
    @Binding var isAnimating: Bool
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<15) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appRecording)
                    .frame(width: 3, height: CGFloat.random(in: 8...24))
                    .animation(
                        isAnimating ? 
                        Animation.easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.05) :
                        .none,
                        value: isAnimating
                    )
            }
        }
    }
}

// Placeholder views that would need to be implemented
struct ModernHistoryView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("History View - To be implemented with modern design")
                .navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct ModernConnectionTestView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Text("Connection Test View - To be implemented with modern design")
                .navigationTitle("Connection Test")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    ModernContentView()
}