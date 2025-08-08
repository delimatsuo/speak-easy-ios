//
//  ContentView.swift
//  Mervyn Talks
//
//  REDESIGNED: Professional voice translation interface with proper proportions
//  Fixes all major design issues: oversized mic button, poor language selectors, misaligned title
//

import SwiftUI
import AVFoundation
import Speech
import Firebase
import UIKit
import FirebaseFirestore

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var translationService = TranslationService.shared
    @StateObject private var usageService = UsageTrackingService.shared
    
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
    @State private var recordingTimer: Timer?
    @State private var recordingDuration = 0
    @State private var connectionStatus = ""
    @State private var showConnectionTest = false
    @State private var isTestingConnection = false
    @State private var processingStartTime: Date?
    @State private var processingTimer: Timer?
    @State private var showCancelButton = false
    @State private var translationTask: Task<Void, Never>?
    
    // Visual feedback
    @State private var pulseAnimation = false
    @State private var soundWaveAnimation = false
    @State private var swapRotation = 0.0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Clean background gradient
                LinearGradient(
                    colors: [
                        DesignConstants.Colors.background,
                        DesignConstants.Colors.secondaryBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignConstants.Layout.contentSpacing) {
                        // Usage Statistics Card
                        UsageStatsCard()
                            .professionalPadding()
                        
                        // Language Selection Section
                        VStack(spacing: DesignConstants.Layout.elementSpacing) {
                            HStack(alignment: .bottom, spacing: DesignConstants.Layout.elementSpacing) {
                                // Source Language
                                ModernLanguageSelector(
                                    selectedLanguage: $sourceLanguage,
                                    languages: availableLanguages,
                                    title: "Speak in",
                                    isSource: true
                                )
                                
                                // Swap Button
                                ModernSwapButton(
                                    sourceLanguage: sourceLanguage,
                                    targetLanguage: targetLanguage,
                                    action: swapLanguages
                                )
                                .padding(.bottom, 6) // Align with language selector buttons
                                
                                // Target Language
                                ModernLanguageSelector(
                                    selectedLanguage: $targetLanguage,
                                    languages: availableLanguages,
                                    title: "Translate to",
                                    isSource: false
                                )
                            }
                        }
                        .professionalPadding()
                        
                        // Recording Section
                        VStack(spacing: DesignConstants.Layout.contentSpacing) {
                            // PROPERLY SIZED Microphone Button (130pt - NOT oversized!)
                            ModernMicrophoneButton(
                                isRecording: $isRecording,
                                isProcessing: isProcessing,
                                isPlaying: isPlaying,
                                action: toggleRecording
                            )
                            
                            // Status Indicator
                            ModernStatusIndicator(
                                status: currentStatus,
                                onCancel: isProcessing ? cancelTranslation : nil
                            )
                        }
                        .professionalPadding()
                        
                        // Text Display Cards
                        VStack(spacing: DesignConstants.Layout.cardSpacing) {
                            if !transcribedText.isEmpty {
                                ModernTextDisplayCard(
                                    title: "You said:",
                                    text: transcribedText,
                                    icon: "mic.fill",
                                    backgroundColor: Color.blue.opacity(0.05),
                                    showReplayButton: false,
                                    onReplay: nil
                                )
                            }
                            
                            if !translatedText.isEmpty {
                                ModernTextDisplayCard(
                                    title: "Translation:",
                                    text: translatedText,
                                    icon: "speaker.wave.2.fill",
                                    backgroundColor: Color.green.opacity(0.05),
                                    showReplayButton: !isPlaying && audioManager.lastAudioData != nil,
                                    onReplay: replayTranslation
                                )
                            }
                        }
                        .professionalPadding()
                    }
                    .padding(.bottom, DesignConstants.Layout.contentSpacing)
                }
            }
            .navigationTitle("Mervyn Talks")
            .navigationBarTitleDisplayMode(.large) // Ensure proper centering
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(DesignConstants.Colors.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showConnectionTest = true }) {
                        Image(systemName: isTestingConnection ? "wifi.circle" : "wifi")
                            .foregroundColor(DesignConstants.Colors.primary)
                    }
                    .disabled(isTestingConnection)
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    // Reset UI state on error acknowledgment
                    resetUIState()
                }
                if !errorMessage.contains("✅") { // Only show retry for actual errors
                    Button("Retry") {
                        retryLastTranslation()
                    }
                }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showConnectionTest) {
                ConnectionTestView()
            }
            .onAppear {
                setupAudio()
                loadLanguages()
                requestPermissions()
            }
            .onChange(of: isRecording) { newValue in
                if newValue {
                    pulseAnimation = true
                    soundWaveAnimation = true
                } else {
                    pulseAnimation = false
                    soundWaveAnimation = false
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
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
        
        // Track usage time for this session
        if isRecording {
            usageService.startTranslationSession()
        } else {
            usageService.endTranslationSession()
        }
    }
    
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
        showCancelButton = true
        
        // Store the translation task so it can be cancelled
        translationTask = Task {
            do {
                // 1. Speech to Text
                print("🎤 [\(Date())] Starting speech-to-text conversion...")
                let transcription = try await audioManager.transcribeAudio(
                    audioURL,
                    language: sourceLanguage
                )
                print("✅ [\(Date())] Speech-to-text completed: \(transcription)")
                
                // Check for cancellation
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.transcribedText = transcription
                }
                
                // 2. Send to translation API with audio response
                print("🔤 [\(Date())] Starting translation request...")
                
                // Check for cancellation before translation
                try Task.checkCancellation()
                
                let response = try await translationService.translateWithAudio(
                    text: transcription,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                print("✅ [\(Date())] Translation completed: \(response.translatedText)")
                
                // Check for cancellation after translation
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.translatedText = response.translatedText
                    // Don't set isProcessing = false yet if we have audio to play
                }
                
                // 3. Play the audio response
                if let audioData = response.audioData {
                    print("🔊 [\(Date())] Playing audio response...")
                    await MainActor.run {
                        self.isProcessing = false
                        self.showCancelButton = false
                    }
                    playTranslation(audioData)
                } else {
                    print("⚠️ [\(Date())] No audio data received")
                    await MainActor.run {
                        self.isProcessing = false
                        self.showCancelButton = false
                    }
                }
                
            } catch is CancellationError {
                print("🚫 [\(Date())] Translation task was cancelled")
                await MainActor.run {
                    self.isProcessing = false
                    self.showCancelButton = false
                    self.processingStartTime = nil
                    // Don't show error for user-initiated cancellation
                }
            } catch {
                let duration = processingStartTime.map { Date().timeIntervalSince($0) } ?? 0
                print("❌ [\(Date())] Translation failed after \(String(format: "%.1f", duration))s: \(error)")
                
                await MainActor.run {
                    self.errorMessage = self.formatErrorMessage(error)
                    self.showError = true
                    self.isProcessing = false
                    self.showCancelButton = false
                    self.processingStartTime = nil
                    
                    // Cancel tracking if translation fails
                    self.usageService.cancelTranslationSession()
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
    
    // MARK: - Computed Properties
    
    private var currentStatus: ModernStatusIndicator.StatusType {
        if isRecording {
            return .recording(duration: recordingDuration)
        } else if isProcessing {
            let elapsed = processingStartTime.map { Date().timeIntervalSince($0) }
            return .processing(elapsed: elapsed)
        } else if isPlaying {
            return .playing
        } else {
            return .idle
        }
    }
    
    private func swapLanguages() {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Swap the languages
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
    }
    
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
        // Use Task groups to prevent race conditions
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // Request microphone permission
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
                // Request speech recognition permission
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
                // Use default languages
                await MainActor.run {
                    self.availableLanguages = Language.defaultLanguages
                }
            }
        }
    }
    
    private func testConnection() {
        Task {
            await MainActor.run {
                isTestingConnection = true
            }
            
            let results = await translationService.testFullConnection()
            
            await MainActor.run {
                errorMessage = results.overallSuccess ? 
                    "✅ All connection tests passed!\n\n\(results.summary)" :
                    "⚠️ Some connection tests failed:\n\n\(results.summary)"
                showError = true
                isTestingConnection = false
            }
        }
    }
    
    private func cancelTranslation() {
        print("🚫 [\(Date())] User cancelled translation")
        
        // Cancel the translation task
        translationTask?.cancel()
        translationTask = nil
        
        // Cancel the service-level request
        translationService.cancelCurrentTranslation()
        
        // Reset UI state
        isProcessing = false
        showCancelButton = false
        processingStartTime = nil
        usageService.cancelTranslationSession()
        
        // Don't show error popup for user-initiated cancellation
        // Just reset the UI quietly
    }
    
    private func resetUIState() {
        isRecording = false
        isProcessing = false
        isPlaying = false
        showCancelButton = false
        processingStartTime = nil
        
        // Cancel any ongoing tasks
        translationTask?.cancel()
        translationTask = nil
        
        stopRecordingTimer()
        stopProcessingTimer()
    }
    
    private func retryLastTranslation() {
        // If we have transcribed text, retry the translation
        if !transcribedText.isEmpty {
            isProcessing = true
            showCancelButton = true
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
                        self.showCancelButton = false
                    }
                    
                    if let audioData = response.audioData {
                        playTranslation(audioData)
                    }
                } catch is CancellationError {
                    await MainActor.run {
                        self.isProcessing = false
                        self.showCancelButton = false
                        self.processingStartTime = nil
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Retry failed: \(self.formatErrorMessage(error))"
                        self.showError = true
                        self.isProcessing = false
                        self.showCancelButton = false
                        self.processingStartTime = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Recording Timer
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            recordingDuration += 1
            if recordingDuration >= 60 {
                // Auto-stop after 60 seconds
                stopRecording()
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    // MARK: - Processing Timer
    
    private func startProcessingTimer() {
        processingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // Force auto-cancel after 35 seconds (5 seconds after service timeout)
            if let startTime = self.processingStartTime,
               Date().timeIntervalSince(startTime) > 35 {
                print("⚠️ [\(Date())] Force-cancelling stuck translation after 35 seconds")
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

// MARK: - Supporting Views

struct LanguagePicker: View {
    @Binding var selectedLanguage: String
    let languages: [Language]
    
    var body: some View {
        Picker("", selection: $selectedLanguage) {
            ForEach(languages) { language in
                Text(language.flag + " " + language.name).tag(language.code)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .frame(minWidth: 120)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.speakEasyPickerBackground)
        .cornerRadius(8)
    }
}

struct HistoryView: View {
    @StateObject private var translationService = TranslationService.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(translationService.translationHistory, id: \.id) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(Language.name(for: item.sourceLanguage), systemImage: "mic")
                            .font(.caption)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                        
                        Label(Language.name(for: item.targetLanguage), systemImage: "speaker.wave.2")
                            .font(.caption)
                        
                        Spacer()
                        
                        if let timestamp = item.timestamp {
                            Text(timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.speakEasyTextSecondary)
                        }
                    }
                    
                    Text(item.originalText)
                        .font(.body)
                        .lineLimit(2)
                    
                    Text(item.translatedText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    if item.hasAudio {
                        Button(action: {
                            // Play saved audio if available
                            if let audioURL = item.audioURL {
                                AudioManager.shared.playAudioFromURL(audioURL)
                            }
                        }) {
                            Label("Play", systemImage: "play.circle")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Translation History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

// MARK: - Connection Test View

struct ConnectionTestView: View {
    @StateObject private var translationService = TranslationService.shared
    @Environment(\.dismiss) var dismiss
    @State private var testResult: ConnectionTestResult?
    @State private var isTesting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Connection Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Test your connection to the translation service")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                if isTesting {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Running connection tests...")
                            .font(.headline)
                    }
                    .padding(40)
                } else if let result = testResult {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Image(systemName: result.overallSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.overallSuccess ? .green : .red)
                                    .font(.title)
                                
                                Text(result.overallSuccess ? "All Tests Passed" : "Some Tests Failed")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            
                            Divider()
                            
                            Text(result.summary)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
                } else {
                    Button(action: runTest) {
                        Label("Run Connection Test", systemImage: "wifi.circle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func runTest() {
        isTesting = true
        testResult = nil
        
        Task {
            let result = await translationService.testFullConnection()
            
            await MainActor.run {
                self.testResult = result
                self.isTesting = false
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UsageTrackingService.shared)
    }
}