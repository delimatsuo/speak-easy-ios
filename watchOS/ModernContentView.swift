//
//  ModernContentView.swift
//  UniversalTranslator Watch App
//
//  COMPLETELY REDESIGNED Apple Watch UI following modern design principles
//  Addresses all critical UI/UX issues with premium experience
//

import SwiftUI
import WatchKit
import WatchConnectivity

struct ModernContentView: View {
    @StateObject private var audioManager = WatchAudioManager()
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    // MARK: - State Management
    @State private var currentState: AppState = .idle
    @State private var sourceLanguageIndex: Int = 0
    @State private var targetLanguageIndex: Int = 1
    @State private var showingLanguageSelection = false
    @State private var isSelectingSourceLanguage = true
    @State private var volumeLevel: Double = 0.5  // Changed from crownValue to volumeLevel for volume control
    
    // MARK: - Translation Data
    @State private var errorMessage = ""
    @State private var translatedText = ""
    @State private var originalText = ""
    @State private var liveTranscription = ""
    @State private var recordingProgress: Double = 0
    @State private var recordingTimer: Timer?
    @State private var lastTranslationAudio: Data?
    @State private var audioLevels: [Float] = Array(repeating: 0.1, count: 12)
    @State private var recordingDuration: Int = 0
    @State private var connectionAnimating = false
    
    // MARK: - Animation States
    @State private var microphoneScale: CGFloat = 1.0
    @State private var recordingPulse: CGFloat = 1.0
    @State private var isPressed = false
    
    // MARK: - Enhanced Language Configuration
    private let languages = [
        ("en", "English", "English", "🇺🇸"),
        ("es", "Spanish", "Español", "🇪🇸"),
        ("fr", "French", "Français", "🇫🇷"),
        ("de", "German", "Deutsch", "🇩🇪"),
        ("it", "Italian", "Italiano", "🇮🇹"),
        ("pt", "Portuguese", "Português", "🇧🇷"),
        ("ja", "Japanese", "日本語", "🇯🇵"),
        ("ko", "Korean", "한국어", "🇰🇷"),
        ("zh", "Chinese", "中文", "🇨🇳"),
        ("ar", "Arabic", "العربية", "🇸🇦"),
        ("ru", "Russian", "Русский", "🇷🇺"),
        ("hi", "Hindi", "हिंदी", "🇮🇳"),
        ("th", "Thai", "ไทย", "🇹🇭"),
        ("vi", "Vietnamese", "Tiếng Việt", "🇻🇳"),
        ("tr", "Turkish", "Türkçe", "🇹🇷"),
        ("pl", "Polish", "Polski", "🇵🇱"),
        ("nl", "Dutch", "Nederlands", "🇳🇱"),
        ("sv", "Swedish", "Svenska", "🇸🇪"),
        ("da", "Danish", "Dansk", "🇩🇰"),
        ("no", "Norwegian", "Norsk", "🇳🇴")
    ]
    
    private var sourceLanguage: String { languages[sourceLanguageIndex].0 }
    private var targetLanguage: String { languages[targetLanguageIndex].0 }
    
    enum AppState {
        case idle
        case recording
        case sending
        case processing
        case playing
        case error
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: WatchSpacing.md) {
                    // MARK: - Header
                    modernHeaderView
                    
                    // MARK: - Language Selection
                    modernLanguageSelector
                    
                    // MARK: - Main Content Area
                    mainContentView
                        .animation(WatchAnimations.smooth, value: currentState)
                    
                    Spacer(minLength: WatchSpacing.sm)
                }
                .padding(.horizontal, WatchSpacing.md)
            }
            .background(Color.watchBackground)
            .ignoresSafeArea(.all, edges: .bottom)
            .navigationTitle("")
            .navigationBarHidden(true)
            .focusable(true)
            .digitalCrownRotation(
                $volumeLevel,
                from: 0.0,
                through: 1.0,
                by: 0.05,  // 5% volume increments
                sensitivity: .medium,
                isContinuous: true,
                isHapticFeedbackEnabled: true
            )
            .onChange(of: volumeLevel) { _, newValue in
                handleVolumeChange(newValue)
            }
        }
        .onAppear {
            setupInitialState()
        }
        .onChange(of: connectivityManager.lastResponse) { _, response in
            handleTranslationResponse(response)
        }
        .sheet(isPresented: $showingLanguageSelection) {
            modernLanguageSelectionSheet
        }
    }
    
    // MARK: - Modern Header View
    
    private var modernHeaderView: some View {
        HStack {
            // Time display
            Text(getCurrentTime())
                .watchTextStyle(.caption)
                .opacity(0.7)
            
            Spacer()
            
            // App title with modern typography
            Text("Translator")
                .watchTextStyle(.headline)
                .foregroundColor(.watchTextPrimary)
            
            Spacer()
            
            // Subtle connection indicator
            modernConnectionIndicator
        }
        .padding(.vertical, WatchSpacing.xs)
    }
    
    // MARK: - Modern Connection Indicator
    
    private var modernConnectionIndicator: some View {
        HStack(spacing: WatchSpacing.xs) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 4, height: 4)
                .scaleEffect(connectionAnimating ? 1.2 : 1.0)
                .animation(
                    connectivityManager.isReachable ? 
                    WatchAnimations.recordingPulse : WatchAnimations.standard,
                    value: connectionAnimating
                )
        }
        .onAppear {
            if connectivityManager.isReachable {
                connectionAnimating = true
            }
        }
        .onChange(of: connectivityManager.isReachable) { _, isReachable in
            connectionAnimating = isReachable
        }
    }
    
    private var connectionStatusColor: Color {
        if connectivityManager.isReachable {
            return Color.watchConnected
        } else {
            return Color.watchDisconnected
        }
    }
    
    // MARK: - Modern Language Selector
    
    private var modernLanguageSelector: some View {
        HStack(spacing: WatchSpacing.sm) {
            // Source language
            modernLanguageCard(
                language: languages[sourceLanguageIndex],
                label: "From",
                isSource: true
            ) {
                isSelectingSourceLanguage = true
                showingLanguageSelection = true
                WatchHaptics.selection()
            }
            
            // Swap button with modern design
            modernSwapButton
            
            // Target language
            modernLanguageCard(
                language: languages[targetLanguageIndex],
                label: "To",
                isSource: false
            ) {
                isSelectingSourceLanguage = false
                showingLanguageSelection = true
                WatchHaptics.selection()
            }
        }
        .watchResponsive()
    }
    
    private func modernLanguageCard(
        language: (String, String, String, String),
        label: String,
        isSource: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: WatchSpacing.xs) {
                Text(label)
                    .watchTextStyle(.caption2)
                    .foregroundColor(.watchTextTertiary)
                
                HStack(spacing: WatchSpacing.xs) {
                    Text(language.3) // Flag emoji
                        .font(.system(size: 12))
                    
                    Text(getLanguageDisplayName(language))
                        .watchTextStyle(.caption)
                        .foregroundColor(.watchTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, WatchSpacing.sm)
            .padding(.horizontal, WatchSpacing.sm)
            .background(Color.watchSurface2)
            .cornerRadius(WatchCornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(label) language: \(language.1)")
    }
    
    private func getLanguageDisplayName(_ language: (String, String, String, String)) -> String {
        let screenWidth = WKInterfaceDevice.current().screenBounds.size.width
        let maxLength = screenWidth > 180 ? 10 : 8 // Adjust for watch size
        
        if language.1.count <= maxLength {
            return language.1
        } else {
            return String(language.1.prefix(maxLength - 1)) + "…"
        }
    }
    
    private var modernSwapButton: some View {
        Button(action: swapLanguages) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.watchAccent)
                .frame(width: 24, height: 24)
                .background(Color.watchSurface2)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Swap languages")
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        Group {
            switch currentState {
            case .idle:
                modernIdleView
            case .recording:
                modernRecordingView
            case .sending, .processing:
                modernProcessingView
            case .playing:
                modernPlayingView
            case .error:
                modernErrorView
            }
        }
        .frame(minHeight: 120)
    }
    
    // MARK: - Modern Idle View
    
    private var modernIdleView: some View {
        VStack(spacing: WatchSpacing.lg) {
            // Modern microphone button
            modernMicrophoneButton
            
            // Instruction text
            Text("Tap to translate")
                .watchTextStyle(.caption)
                .foregroundColor(.watchTextTertiary)
            
            // Volume indicator
            HStack(spacing: WatchSpacing.xs) {
                Image(systemName: volumeIconName)
                    .font(.system(size: 10))
                    .foregroundColor(.watchTextTertiary)
                Text("Volume: \(Int(volumeLevel * 100))%")
                    .watchTextStyle(.caption2)
                    .foregroundColor(.watchTextTertiary)
            }
            .opacity(0.8)
            
            // Credits and status (subtle)
            modernCreditsView
        }
    }
    
    private var modernMicrophoneButton: some View {
        Button(action: handleRecordingTap) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(WatchGradients.microphoneButton)
                    .frame(width: 100, height: 100)
                    .scaleEffect(microphoneScale)
                
                // Main button
                Circle()
                    .fill(WatchGradients.primary)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(Color.watchTextPrimary.opacity(0.1), lineWidth: 1)
                    )
                
                // Microphone icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(WatchAnimations.bounce, value: isPressed)
        .accessibilityLabel("Start recording")
        .accessibilityHint("Tap to begin voice translation")
    }
    
    // MARK: - Modern Recording View
    
    private var modernRecordingView: some View {
        VStack(spacing: WatchSpacing.lg) {
            // Recording indicator
            modernRecordingIndicator
            
            // Live transcription
            modernTranscriptionView
            
            // Audio visualization
            modernWaveformView
            
            // Stop button
            modernStopButton
        }
    }
    
    private var modernRecordingIndicator: some View {
        HStack(spacing: WatchSpacing.sm) {
            // Pulsing record dot
            Circle()
                .fill(Color.watchRecording)
                .frame(width: 8, height: 8)
                .scaleEffect(recordingPulse)
                .animation(WatchAnimations.recordingPulse, value: recordingPulse)
            
            Text("Recording")
                .watchTextStyle(.caption)
                .foregroundColor(.watchRecording)
            
            Spacer()
            
            Text(formatTime(recordingDuration / 10)) // Convert from deciseconds
                .watchTextStyle(.caption)
                .foregroundColor(.watchTextSecondary)
        }
        .onAppear {
            recordingPulse = 1.3
        }
        .onDisappear {
            recordingPulse = 1.0
        }
    }
    
    private var modernTranscriptionView: some View {
        VStack(alignment: .leading, spacing: WatchSpacing.xs) {
            if !liveTranscription.isEmpty {
                Text("You're saying:")
                    .watchTextStyle(.caption2)
                    .foregroundColor(.watchTextTertiary)
                
                ScrollView {
                    Text(liveTranscription)
                        .watchTextStyle(.body)
                        .foregroundColor(.watchTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxHeight: 40)
            } else {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .watchAccent))
                        .scaleEffect(0.7)
                    
                    Text("Listening...")
                        .watchTextStyle(.body)
                        .foregroundColor(.watchTextSecondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, WatchSpacing.sm)
        .padding(.horizontal, WatchSpacing.sm)
        .background(Color.watchSurface2)
        .cornerRadius(WatchCornerRadius.md)
    }
    
    private var modernWaveformView: some View {
        ModernWaveformVisualization(audioLevels: audioLevels)
            .frame(height: 20)
    }
    
    private var modernStopButton: some View {
        Button(action: handleRecordingTap) {
            HStack {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Stop")
                    .watchTextStyle(.button)
            }
            .foregroundColor(.white)
            .padding(.vertical, WatchSpacing.sm)
            .padding(.horizontal, WatchSpacing.lg)
            .background(Color.watchError)
            .cornerRadius(WatchCornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Stop recording")
    }
    
    // MARK: - Modern Processing View
    
    private var modernProcessingView: some View {
        VStack(spacing: WatchSpacing.lg) {
            // Animated progress indicator
            ZStack {
                Circle()
                    .stroke(Color.watchSurface2, lineWidth: 3)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        WatchGradients.primary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(connectionAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                        value: connectionAnimating
                    )
            }
            .onAppear {
                connectionAnimating = true
            }
            
            Text(currentState == .sending ? "Sending..." : "Translating...")
                .watchTextStyle(.headline)
                .foregroundColor(.watchTextPrimary)
            
            if !originalText.isEmpty {
                Text("✓ \(originalText)")
                    .watchTextStyle(.caption)
                    .foregroundColor(.watchTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Modern Playing View
    
    private var modernPlayingView: some View {
        VStack(spacing: WatchSpacing.md) {
            // Source text card
            modernTextCard(
                title: "You said:",
                text: originalText,
                color: .watchTextSecondary
            )
            
            // Arrow indicator
            Image(systemName: "arrow.down")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.watchAccent)
            
            // Translation card with emphasis
            modernTextCard(
                title: "Translation:",
                text: translatedText,
                color: .watchAccent,
                isHighlighted: true
            )
            
            // Playing indicator with volume level
            HStack(spacing: WatchSpacing.xs) {
                Image(systemName: volumeIconName)
                    .font(.system(size: 10))
                    .foregroundColor(.watchSuccess)
                Text("Playing...")
                    .watchTextStyle(.caption)
                    .foregroundColor(.watchSuccess)
                Spacer()
                Text("\(Int(volumeLevel * 100))%")
                    .watchTextStyle(.caption2)
                    .foregroundColor(.watchTextSecondary)
            }
            
            // New translation button
            modernActionButton(
                title: "New Translation",
                icon: "plus.circle",
                color: .watchAccent
            ) {
                resetForNewTranslation()
            }
        }
    }
    
    // MARK: - Modern Error View
    
    private var modernErrorView: some View {
        VStack(spacing: WatchSpacing.lg) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.watchWarning)
            
            // Error message
            Text(errorMessage)
                .watchTextStyle(.body)
                .foregroundColor(.watchTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Action buttons
            HStack(spacing: WatchSpacing.sm) {
                modernActionButton(
                    title: "Cancel",
                    icon: "xmark",
                    color: .watchTextSecondary,
                    style: .secondary
                ) {
                    resetForNewTranslation()
                }
                
                modernActionButton(
                    title: "Retry",
                    icon: "arrow.clockwise",
                    color: .watchAccent
                ) {
                    resetForNewTranslation()
                }
            }
        }
    }
    
    // MARK: - Modern Credits View
    
    private var modernCreditsView: some View {
        VStack(spacing: WatchSpacing.xs) {
            if !connectivityManager.isReachable {
                HStack(spacing: WatchSpacing.xs) {
                    Image(systemName: "iphone")
                        .font(.system(size: 8))
                        .foregroundColor(.watchWarning)
                    
                    Text("Open iPhone app")
                        .watchTextStyle(.caption2)
                        .foregroundColor(.watchWarning)
                }
            } else if connectivityManager.creditsRemaining > 0 {
                HStack(spacing: WatchSpacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .foregroundColor(creditColor)
                    
                    Text("\(connectivityManager.creditsRemaining)s")
                        .watchTextStyle(.caption2)
                        .foregroundColor(creditColor)
                }
            }
        }
    }
    
    private var creditColor: Color {
        connectivityManager.creditsRemaining <= 60 ? .watchWarning : .watchTextTertiary
    }
    
    private var volumeIconName: String {
        if volumeLevel <= 0 {
            return "speaker.slash.fill"
        } else if volumeLevel < 0.33 {
            return "speaker.fill"
        } else if volumeLevel < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }
    
    // MARK: - Helper Views
    
    private func modernTextCard(
        title: String,
        text: String,
        color: Color,
        isHighlighted: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: WatchSpacing.xs) {
            Text(title)
                .watchTextStyle(.caption2)
                .foregroundColor(.watchTextTertiary)
            
            Text(text)
                .watchTextStyle(isHighlighted ? .headline : .body)
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, WatchSpacing.sm)
        .padding(.horizontal, WatchSpacing.sm)
        .background(
            isHighlighted ? 
            Color.watchAccent.opacity(0.1) : Color.watchSurface2
        )
        .cornerRadius(WatchCornerRadius.md)
    }
    
    private func modernActionButton(
        title: String,
        icon: String,
        color: Color,
        style: ButtonStyle = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: WatchSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .watchTextStyle(.caption)
            }
            .foregroundColor(style == .primary ? .white : color)
            .padding(.vertical, WatchSpacing.sm)
            .padding(.horizontal, WatchSpacing.md)
            .background(
                style == .primary ? color : Color.watchSurface2
            )
            .cornerRadius(WatchCornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    enum ButtonStyle {
        case primary, secondary
    }
    
    // MARK: - Modern Language Selection Sheet
    
    private var modernLanguageSelectionSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                    modernLanguageRow(
                        language: language,
                        index: index,
                        isSelected: isSelectedLanguage(index)
                    ) {
                        selectLanguage(index)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle(isSelectingSourceLanguage ? "From" : "To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingLanguageSelection = false
                    }
                    .foregroundColor(.watchAccent)
                }
            }
        }
    }
    
    private func modernLanguageRow(
        language: (String, String, String, String),
        index: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(language.3) // Flag
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.1) // English name
                        .watchTextStyle(.body)
                        .foregroundColor(.watchTextPrimary)
                    
                    if language.2 != language.1 { // Native name if different
                        Text(language.2)
                            .watchTextStyle(.caption)
                            .foregroundColor(.watchTextSecondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.watchAccent)
                }
            }
            .padding(.vertical, WatchSpacing.xs)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    
    private func setupInitialState() {
        connectivityManager.activate()
        connectivityManager.requestCreditsUpdate()
    }
    
    private func getCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func isSelectedLanguage(_ index: Int) -> Bool {
        if isSelectingSourceLanguage {
            return index == sourceLanguageIndex
        } else {
            return index == targetLanguageIndex
        }
    }
    
    private func selectLanguage(_ index: Int) {
        if isSelectingSourceLanguage {
            sourceLanguageIndex = index
        } else {
            targetLanguageIndex = index
        }
        showingLanguageSelection = false
        WatchHaptics.selection()
    }
    
    private func handleVolumeChange(_ value: Double) {
        // Update the audio player volume if it's currently playing
        if let player = audioManager.audioPlayer {
            player.volume = Float(value)
        }
        
        // Provide haptic feedback at min/max volume
        if value <= 0.0 || value >= 1.0 {
            WatchHaptics.selection()
        }
    }
    
    private func swapLanguages() {
        let tempIndex = sourceLanguageIndex
        sourceLanguageIndex = targetLanguageIndex
        targetLanguageIndex = tempIndex
        WatchHaptics.selection()
    }
    
    private func resetForNewTranslation() {
        currentState = .idle
        liveTranscription = ""
        originalText = ""
        translatedText = ""
        errorMessage = ""
        recordingDuration = 0
        recordingProgress = 0
        connectionAnimating = false
    }
    
    // MARK: - Recording Actions
    
    private func handleRecordingTap() {
        isPressed = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isPressed = false
        }
        
        switch currentState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        default:
            break
        }
    }
    
    private func startRecording() {
        resetForNewTranslation()
        
        guard let session = WCSession.default as WCSession? else {
            errorMessage = "Watch connectivity not supported"
            currentState = .error
            WatchHaptics.error()
            return
        }
        
        if session.activationState != .activated {
            errorMessage = "Connecting to iPhone..."
            currentState = .error
            WatchHaptics.error()
            connectivityManager.activate()
            return
        }
        
        if !connectivityManager.isReachable {
            errorMessage = "Open iPhone app first"
            currentState = .error
            WatchHaptics.error()
            return
        }
        
        if connectivityManager.creditsRemaining == 0 {
            errorMessage = "No credits remaining"
            currentState = .error
            WatchHaptics.error()
            return
        }
        
        audioManager.startRecording { success in
            if success {
                currentState = .recording
                recordingProgress = 0
                recordingDuration = 0
                startRecordingTimer()
                WatchHaptics.start()
                
                // Simulate live transcription
                simulateLiveTranscription()
            } else {
                errorMessage = "Failed to start recording"
                currentState = .error
                WatchHaptics.error()
            }
        }
    }
    
    private func stopRecording() {
        stopRecordingTimer()
        currentState = .sending
        
        audioManager.stopRecording { audioURL in
            if let audioURL = audioURL {
                sendAudioToPhone(audioURL)
            } else {
                errorMessage = "Failed to save recording"
                currentState = .error
                WatchHaptics.error()
            }
        }
    }
    
    private func sendAudioToPhone(_ audioURL: URL) {
        currentState = .processing
        
        let request = TranslationRequest(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            audioFileURL: audioURL
        )
        
        connectivityManager.sendTranslationRequest(request) { success in
            if success {
                self.waitForResponse(requestId: request.requestId, attempts: 0)
            } else {
                errorMessage = "Failed to send to iPhone"
                currentState = .error
                WatchHaptics.error()
            }
        }
    }
    
    private func waitForResponse(requestId: UUID, attempts: Int) {
        if let response = connectivityManager.lastResponse {
            handleTranslationResponse(response)
            connectivityManager.lastResponse = nil
        } else if attempts < 30 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.currentState == .processing {
                    self.waitForResponse(requestId: requestId, attempts: attempts + 1)
                }
            }
        } else {
            errorMessage = "Translation timeout"
            currentState = .error
            WatchHaptics.error()
        }
    }
    
    private func handleTranslationResponse(_ response: TranslationResponse?) {
        guard let response = response else {
            errorMessage = "No response from iPhone"
            currentState = .error
            WatchHaptics.error()
            return
        }
        
        connectivityManager.lastResponse = nil
        
        if let error = response.error {
            errorMessage = error
            currentState = .error
            WatchHaptics.error()
        } else if response.translatedText.isEmpty {
            errorMessage = "Empty translation received"
            currentState = .error
            WatchHaptics.error()
        } else {
            originalText = response.originalText
            translatedText = response.translatedText
            
            if let audioData = response.audioData {
                lastTranslationAudio = audioData
                playTranslation(audioData)
            } else {
                lastTranslationAudio = nil
                currentState = .idle
                WatchHaptics.success()
            }
        }
    }
    
    private func playTranslation(_ audioData: Data) {
        currentState = .playing
        
        audioManager.playAudio(audioData) { success in
            // Set the initial volume for the audio player
            if let player = self.audioManager.audioPlayer {
                player.volume = Float(self.volumeLevel)
            }
            currentState = .idle
            WatchHaptics.success()
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingProgress += 0.1 / AudioConstants.maxRecordingDuration
            recordingDuration += 1
            
            if recordingProgress >= 1.0 {
                stopRecording()
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func simulateLiveTranscription() {
        let sampleTexts = ["Hello", "Hello how", "Hello how are", "Hello how are you", "Hello how are you today"]
        var index = 0
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if currentState == .recording && index < sampleTexts.count {
                liveTranscription = sampleTexts[index]
                index += 1
                
                // Update audio levels for waveform
                audioLevels = (0..<12).map { _ in Float.random(in: 0.1...1.0) }
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Modern Waveform Visualization

struct ModernWaveformVisualization: View {
    let audioLevels: [Float]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<audioLevels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.watchAccent,
                                Color.watchAccent.opacity(0.7)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 2, height: CGFloat(getBarHeight(for: index)))
                    .animation(.easeInOut(duration: 0.1), value: audioLevels)
            }
        }
    }
    
    private func getBarHeight(for index: Int) -> Float {
        if index < audioLevels.count {
            return max(2, audioLevels[index] * 20)
        }
        return 2
    }
}

// MARK: - Preview

struct ModernContentView_Previews: PreviewProvider {
    static var previews: some View {
        ModernContentView()
    }
}