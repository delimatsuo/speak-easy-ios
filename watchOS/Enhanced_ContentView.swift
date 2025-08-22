//
//  Enhanced_ContentView.swift
//  UniversalTranslator Watch App
//
//  Enhanced UI with Digital Crown language selection, live transcription, and improved visual hierarchy
//

import SwiftUI
import WatchKit
import WatchConnectivity

struct Enhanced_ContentView: View {
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
    
    // MARK: - Enhanced Header View
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
    
    // MARK: - Enhanced Language Selection View
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
    
    // MARK: - Idle State View (Enhanced)
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
    
    // MARK: - NEW: Enhanced Recording View with Live Transcription
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
    
    // MARK: - Processing State View (Enhanced)
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
    
    // MARK: - Playing State View (Enhanced)
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
    
    // MARK: - Error State View (Enhanced)
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
    
    // MARK: - Credits Status View
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
    
    // MARK: - Language Selection Sheet
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
    
    // MARK: - Recording Actions (Using existing logic)
    
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
        // Clear previous results
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
            connectivityManager.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.connectivityManager.requestCreditsUpdate()
            }
            return
        }
        
        // Check credits
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
                
                // Simulate live transcription updates (you would integrate real STT here)
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
    
    // NEW: Simulate live transcription (replace with real implementation)
    private func simulateLiveTranscription() {
        let sampleTexts = ["Hello", "Hello how", "Hello how are", "Hello how are you", "Hello how are you today"]
        var index = 0
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if currentState == .recording && index < sampleTexts.count {
                liveTranscription = sampleTexts[index]
                index += 1
                
                // Simulate audio levels
                audioLevels = (0..<20).map { _ in Float.random(in: 0.1...1.0) }
            } else {
                timer.invalidate()
            }
        }
    }
    
    // MARK: - Existing methods (unchanged)
    
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
        }
    }
    
    private func handleTranslationResponse(_ response: TranslationResponse?) {
        guard let response = response else {
            errorMessage = "No response from iPhone"
            currentState = .error
            return
        }
        
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
                lastTranslationAudio = audioData
                playTranslation(audioData)
            } else {
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
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingProgress += 0.1 / AudioConstants.maxRecordingDuration
            recordingDuration += 1  // Increment by 0.1 seconds (100ms)
            
            if recordingProgress >= 1.0 {
                stopRecording()
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - NEW: Waveform Visualization Component
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

// MARK: - Preview
struct Enhanced_ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Enhanced_ContentView()
    }
}