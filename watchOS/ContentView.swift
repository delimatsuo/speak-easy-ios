//
//  ContentView.swift
//  UniversalTranslator Watch App
//
//  MODERNIZED Apple Watch UI - Premium design with enhanced UX
//  Uses ModernContentView for the new design system
//

import SwiftUI
import WatchKit
import WatchConnectivity

struct ContentView: View {
    
    var body: some View {
        // Use the modern redesigned UI
        ModernContentView()
    }
}

// MARK: - Legacy ContentView (Preserved for reference)

struct LegacyContentView: View {
    @StateObject private var audioManager = WatchAudioManager()
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    // Enhanced state management
    @State private var currentState: AppState = .idle
    @State private var sourceLanguageIndex: Int = 0  // For Digital Crown
    @State private var targetLanguageIndex: Int = 1  // For Digital Crown
    @State private var crownValue: Double = 0
    @State private var showingLanguageSelection = false
    @State private var isSelectingSourceLanguage = true
    
    // Translation data
    @State private var errorMessage = ""
    @State private var translatedText = ""
    @State private var originalText = ""
    @State private var liveTranscription = ""  // NEW: Live transcription
    @State private var recordingProgress: Double = 0
    @State private var recordingTimer: Timer?
    @State private var lastTranslationAudio: Data?
    @State private var audioLevels: [Float] = Array(repeating: 0.1, count: 20)  // NEW: Waveform data
    @State private var recordingDuration: Int = 0  // NEW: Recording duration
    @State private var silenceCountdown: Int = 0  // NEW: Auto-stop countdown
    
    // Language configuration - Enhanced with native names
    private let languages = [
        ("en", "English", "English"),
        ("es", "Spanish", "Español"),
        ("fr", "French", "Français"),
        ("de", "German", "Deutsch"),
        ("it", "Italian", "Italiano"),
        ("pt", "Portuguese", "Português"),
        ("ja", "Japanese", "日本語"),
        ("ko", "Korean", "한국어"),
        ("zh", "Chinese", "中文"),
        ("ar", "Arabic", "العربية"),
        ("ru", "Russian", "Русский"),
        ("hi", "Hindi", "हिंदी"),
        ("th", "Thai", "ไทย"),
        ("vi", "Vietnamese", "Tiếng Việt"),
        ("tr", "Turkish", "Türkçe"),
        ("pl", "Polish", "Polski"),
        ("nl", "Dutch", "Nederlands"),
        ("sv", "Swedish", "Svenska"),
        ("da", "Danish", "Dansk"),
        ("no", "Norwegian", "Norsk")
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
            VStack(spacing: 8) {
                // ENHANCED: Header with time and connection status
                headerView
                
                // ENHANCED: Language selection with better visual design
                languageSelectionView
                
                // ENHANCED: Main content based on current state
                Group {
                    switch currentState {
                    case .idle:
                        idleStateView
                    case .recording:
                        enhancedRecordingView  // NEW: Enhanced recording with live transcription
                    case .sending, .processing:
                        processingStateView
                    case .playing:
                        playingStateView
                    case .error:
                        errorStateView
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentState)
                
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .background(Color.black)
            .ignoresSafeArea()
            .navigationTitle("")
            .navigationBarHidden(true)
            .focusable(true)
            .digitalCrownRotation($crownValue, from: 0, through: Double(languages.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crownValue) { _, newValue in
                handleCrownRotation(newValue)
            }
        }
        .onAppear {
            connectivityManager.activate()
            connectivityManager.requestCreditsUpdate()
        }
        .onChange(of: connectivityManager.lastResponse) { _, response in
            handleTranslationResponse(response)
        }
        .sheet(isPresented: $showingLanguageSelection) {
            languageSelectionSheet
        }
    }
    
    // MARK: - Enhanced View Components
    
    // ENHANCED: Header with time and connection status
    private var headerView: some View {
        HStack {
            Text(getCurrentTime())
                .font(.caption2)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("Translator")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            // Enhanced connection indicator
            Circle()
                .fill(connectivityManager.isReachable ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
        }
        .padding(.top, 2)
    }
    
    // ENHANCED: Language selection with better visual design
    private var languageSelectionView: some View {
        HStack(spacing: 8) {
            // From language - Enhanced design
            Button(action: {
                isSelectingSourceLanguage = true
                showingLanguageSelection = true
            }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("From")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(languages[sourceLanguageIndex].1)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                )
            }
            .accessibilityLabel("Select source language: \(languages[sourceLanguageIndex].1)")
            
            // ENHANCED: Swap button with better visual design
            Button(action: swapLanguages) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("Swap languages")
            
            // To language - Enhanced design
            Button(action: {
                isSelectingSourceLanguage = false
                showingLanguageSelection = true
            }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(languages[targetLanguageIndex].1)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                )
            }
            .accessibilityLabel("Select target language: \(languages[targetLanguageIndex].1)")
        }
    }
    
    // ENHANCED: Idle state with improved design
    private var idleStateView: some View {
        VStack(spacing: 12) {
            // Enhanced record button
            Button(action: handleRecordingTap) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.blue, lineWidth: 3)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 74, height: 74)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .accessibilityLabel("Start recording")
            .accessibilityHint("Tap to begin voice translation")
            
            Text("Tap to translate")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Credits and connection status
            creditsStatusView
        }
    }
    
    // NEW: Enhanced Recording View with Live Transcription
    private var enhancedRecordingView: some View {
        VStack(spacing: 8) {
            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(currentState == .recording ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: currentState == .recording)
                
                Text("Recording...")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Spacer()
                
                Text(formatTime(recordingDuration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // NEW: Live transcription display
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if !liveTranscription.isEmpty {
                        Text("You're saying:")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Text(liveTranscription)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Listening...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 60)
            
            // NEW: Audio waveform visualization
            WaveformView(audioLevels: audioLevels)
                .frame(height: 30)
            
            // Auto-stop countdown (if applicable)
            if silenceCountdown > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    Text("Auto-stop in \(silenceCountdown)s")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            // Stop button
            Button(action: handleRecordingTap) {
                HStack {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Stop")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.red)
                )
            }
            .accessibilityLabel("Stop recording")
        }
    }
    
    // ENHANCED: Processing state
    private var processingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text(currentState == .sending ? "Sending to iPhone..." : "Translating...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            if !originalText.isEmpty {
                Text("✓ \(originalText)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // ENHANCED: Playing state with better layout
    private var playingStateView: some View {
        VStack(spacing: 8) {
            // Source text
            VStack(alignment: .leading, spacing: 4) {
                Text("You said:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(originalText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Translation with enhanced visibility
            VStack(alignment: .leading, spacing: 4) {
                Text("Translation:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(translatedText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Playing indicator
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.green)
                Text("Playing...")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            // New translation button
            Button("New Translation") {
                resetForNewTranslation()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue)
            )
        }
    }
    
    // ENHANCED: Error state with cancel and retry
    private var errorStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text(errorMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Retry and cancel buttons
            HStack(spacing: 8) {
                Button("Cancel") {
                    resetForNewTranslation()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.gray.opacity(0.2))
                )
                
                Button("Retry") {
                    if currentState == .error {
                        resetForNewTranslation()
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue)
                )
            }
        }
    }
    
    // Credits and status view
    private var creditsStatusView: some View {
        VStack(spacing: 4) {
            // Connection indicator
            HStack {
                Image(systemName: connectivityManager.isReachable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundColor(connectivityManager.isReachable ? .green : .orange)
                Text(connectivityManager.isReachable ? "Connected" : "Disconnected")
                    .font(.caption2)
                    .foregroundColor(connectivityManager.isReachable ? .green : .orange)
            }
            
            // Credits display
            if connectivityManager.creditsRemaining > 0 {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("\(connectivityManager.creditsRemaining)s")
                        .font(.caption)
                }
                .foregroundColor(connectivityManager.creditsRemaining <= 60 ? .orange : .secondary)
            }
        }
    }
    
    // ENHANCED: Language selection sheet with native names
    private var languageSelectionSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                    Button(action: {
                        if isSelectingSourceLanguage {
                            sourceLanguageIndex = index
                        } else {
                            targetLanguageIndex = index
                        }
                        showingLanguageSelection = false
                        WKInterfaceDevice.current().play(.click)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(language.1)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                
                                if language.2 != language.1 {
                                    Text(language.2)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            if (isSelectingSourceLanguage && index == sourceLanguageIndex) ||
                               (!isSelectingSourceLanguage && index == targetLanguageIndex) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle(isSelectingSourceLanguage ? "From Language" : "To Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingLanguageSelection = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
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
    
    private func handleCrownRotation(_ value: Double) {
        let newIndex = Int(value.rounded())
        if newIndex >= 0 && newIndex < languages.count {
            // Update the appropriate language based on current selection
            if isSelectingSourceLanguage {
                if newIndex != sourceLanguageIndex {
                    sourceLanguageIndex = newIndex
                    WKInterfaceDevice.current().play(.click)
                }
            } else {
                if newIndex != targetLanguageIndex {
                    targetLanguageIndex = newIndex
                    WKInterfaceDevice.current().play(.click)
                }
            }
        }
    }
    
    private func swapLanguages() {
        let tempIndex = sourceLanguageIndex
        sourceLanguageIndex = targetLanguageIndex
        targetLanguageIndex = tempIndex
        WKInterfaceDevice.current().play(.click)
    }
    
    private func resetForNewTranslation() {
        currentState = .idle
        liveTranscription = ""
        originalText = ""
        translatedText = ""
        errorMessage = ""
        recordingDuration = 0
        silenceCountdown = 0
        recordingProgress = 0
    }
    
    // MARK: - Actions
    
    private func handleRecordingTap() {
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
        // Clear previous translation results using enhanced reset
        resetForNewTranslation()
        
        // Check WCSession activation first
        guard let session = WCSession.default as WCSession? else {
            errorMessage = "Watch connectivity not supported"
            currentState = .error
            return
        }
        
        if session.activationState != .activated {
            errorMessage = "Connecting to iPhone..."
            currentState = .error
            connectivityManager.activate()
            return
        }
        
        // Check iPhone connection
        if !connectivityManager.isReachable {
            errorMessage = "Open iPhone app first"
            currentState = .error
            // Try to activate and request credits to test connection
            connectivityManager.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.connectivityManager.requestCreditsUpdate()
            }
            return
        }
        
        // Check credits (allow recording if credits > 0 or unlimited)
        if connectivityManager.creditsRemaining == 0 {
            errorMessage = "No credits remaining"
            currentState = .error
            return
        }
        
        audioManager.startRecording { success in
            if success {
                currentState = .recording
                recordingProgress = 0
                recordingDuration = 0
                startRecordingTimer()
                WKInterfaceDevice.current().play(.start)
                
                // NEW: Simulate live transcription updates
                simulateLiveTranscription()
            } else {
                errorMessage = "Failed to start recording"
                currentState = .error
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
        
        print("📤 Watch: Sending request with ID: \(request.requestId)")
        
        connectivityManager.sendTranslationRequest(request) { success in
            if success {
                print("✅ Watch: Request sent, waiting for response...")
                // Monitor for response
                self.waitForResponse(requestId: request.requestId, attempts: 0)
            } else {
                errorMessage = "Failed to send to iPhone"
                currentState = .error
            }
        }
    }
    
    private func waitForResponse(requestId: UUID, attempts: Int) {
        // Check if response arrived
        if let response = connectivityManager.lastResponse {
            print("📥 Watch: Response arrived!")
            handleTranslationResponse(response)
            // Clear for next request
            connectivityManager.lastResponse = nil
        } else if attempts < 30 { // Wait up to 30 seconds
            // Keep waiting
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.currentState == .processing {
                    self.waitForResponse(requestId: requestId, attempts: attempts + 1)
                }
            }
        } else {
            // Timeout
            errorMessage = "Translation timeout"
            currentState = .error
        }
    }
    
    private func handleTranslationResponse(_ response: TranslationResponse?) {
        guard let response = response else { 
            print("❌ Watch: No response received")
            errorMessage = "No response from iPhone"
            currentState = .error
            return
        }
        
        print("📥 Watch: Processing response - Original: '\(response.originalText)', Translated: '\(response.translatedText)', Error: \(response.error ?? "none")")
        
        // Clear the lastResponse to prevent replaying old responses
        connectivityManager.lastResponse = nil
        
        if let error = response.error {
            errorMessage = error
            currentState = .error
            WKInterfaceDevice.current().play(.failure)
        } else if response.translatedText.isEmpty {
            errorMessage = "Empty translation received"
            currentState = .error
            WKInterfaceDevice.current().play(.failure)
        } else {
            originalText = response.originalText
            translatedText = response.translatedText
            
            if let audioData = response.audioData {
                print("🎵 Watch: Received audio data: \(audioData.count) bytes")
                // Store audio for replay
                lastTranslationAudio = audioData
                playTranslation(audioData)
            } else {
                print("⚠️ Watch: No audio data in response - text only")
                lastTranslationAudio = nil
                currentState = .idle
                WKInterfaceDevice.current().play(.success)
            }
        }
    }
    
    private func playTranslation(_ audioData: Data) {
        currentState = .playing
        
        audioManager.playAudio(audioData) { success in
            currentState = .idle
            WKInterfaceDevice.current().play(success ? .success : .failure)
        }
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingProgress += 0.1 / AudioConstants.maxRecordingDuration
            recordingDuration += 1  // Increment by 100ms (0.1 seconds)
            
            if recordingProgress >= 1.0 {
                stopRecording()
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Replay Function
    
    private func replayLastTranslation() {
        guard let audioData = lastTranslationAudio else {
            print("⚠️ Watch: No audio to replay")
            return
        }
        
        print("🔁 Watch: Replaying last translation (\(audioData.count) bytes)")
        playTranslation(audioData)
    }
    
    // NEW: Simulate live transcription (replace with real implementation)
    private func simulateLiveTranscription() {
        let sampleTexts = ["Hello", "Hello how", "Hello how are", "Hello how are you", "Hello how are you today"]
        var index = 0
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if currentState == .recording && index < sampleTexts.count {
                liveTranscription = sampleTexts[index]
                index += 1
                
                // Simulate audio levels for waveform
                audioLevels = (0..<20).map { _ in Float.random(in: 0.1...1.0) }
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - NEW Enhanced Components

// NEW: Waveform Visualization Component
struct WaveformView: View {
    let audioLevels: [Float]
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 3, height: CGFloat(getBarHeight(for: index)))
                    .animation(.easeInOut(duration: 0.1), value: audioLevels)
            }
        }
    }
    
    private func getBarHeight(for index: Int) -> Float {
        if index < audioLevels.count {
            return max(2, audioLevels[index] * 30) // Scale to visible range
        }
        return 2
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}