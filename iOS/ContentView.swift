//
//  ContentView.swift
//  UniversalTranslator
//
//  Voice-based translation interface
//

import SwiftUI
import AVFoundation
import Speech
import Firebase
import UIKit
import FirebaseFirestore
// Import local modules for usage tracking

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
    
    // Visual feedback
    @State private var pulseAnimation = false
    @State private var soundWaveAnimation = false
    @State private var swapRotation = 0.0
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient matching icon colors
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.99, blue: 0.99),
                        Color(red: 0.94, green: 0.97, blue: 0.98)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Usage Statistics
                    UsageStatisticsView()
                        .padding(.horizontal)
                    
                    // Language Selection
                    HStack(spacing: 20) {
                        VStack {
                            Text("Speak in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            LanguagePicker(
                                selectedLanguage: $sourceLanguage,
                                languages: availableLanguages
                            )
                        }
                        
                        VStack(spacing: 2) {
                            Button(action: swapLanguages) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.00, green: 0.60, blue: 0.40).opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "arrow.2.circlepath")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(Color(red: 0.00, green: 0.60, blue: 0.40))
                                        .rotationEffect(.degrees(swapRotation))
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(sourceLanguage == targetLanguage)
                            .opacity(sourceLanguage == targetLanguage ? 0.3 : 1.0)
                            .accessibilityLabel("Swap languages")
                            .accessibilityHint("Swaps source and target languages for translation")
                            
                            Text("\(languageCode(sourceLanguage))→\(languageCode(targetLanguage))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("Translate to")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            LanguagePicker(
                                selectedLanguage: $targetLanguage,
                                languages: availableLanguages
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recording Button and Status
                    VStack(spacing: 20) {
                        // Microphone Button
                        ZStack {
                            // Pulse animation circle
                            if isRecording {
                                Circle()
                                    .fill(Color(red: 0.95, green: 0.26, blue: 0.21).opacity(0.3))
                                    .frame(width: 180, height: 180)
                                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                                    .animation(
                                        Animation.easeInOut(duration: 0.8)
                                            .repeatForever(autoreverses: true),
                                        value: pulseAnimation
                                    )
                            }
                            
                            // Main button
                            Button(action: toggleRecording) {
                                ZStack {
                                    if isRecording {
                                        Circle()
                                            .fill(Color(red: 0.95, green: 0.26, blue: 0.21))
                                            .frame(width: 150, height: 150)
                                    } else {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color(red: 0.00, green: 0.60, blue: 0.40), Color(red: 0.00, green: 0.40, blue: 0.75)]),
                                                    startPoint: .bottomTrailing,
                                                    endPoint: .topLeading
                                                )
                                            )
                                            .frame(width: 150, height: 150)
                                    }
                                    
                                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white)
                                }
                            }
                            .disabled(isProcessing || isPlaying)
                            .scaleEffect(isRecording ? 1.1 : 1.0)
                            .animation(.spring(), value: isRecording)
                        }
                        
                        // Status Text
                        if isRecording {
                            VStack(spacing: 5) {
                                Text("Listening...")
                                    .font(.headline)
                                    .foregroundColor(Color(red: 0.95, green: 0.26, blue: 0.21))
                                
                                Text(formatDuration(recordingDuration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                // Sound wave visualization
                                HStack(spacing: 3) {
                                    ForEach(0..<20) { i in
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(red: 0.95, green: 0.26, blue: 0.21))
                                            .frame(width: 3, height: CGFloat.random(in: 10...30))
                                            .animation(
                                                Animation.easeInOut(duration: 0.3)
                                                    .repeatForever(autoreverses: true)
                                                    .delay(Double(i) * 0.05),
                                                value: soundWaveAnimation
                                            )
                                    }
                                }
                                .frame(height: 30)
                                .padding(.horizontal)
                            }
                        } else if isProcessing {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.00, green: 0.40, blue: 0.75)))
                                    .scaleEffect(1.5)
                                
                                Text("Translating...")
                                    .font(.headline)
                                    .foregroundColor(Color(red: 0.00, green: 0.40, blue: 0.75))
                            }
                        } else if isPlaying {
                            VStack(spacing: 10) {
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(Color(red: 0.00, green: 0.60, blue: 0.40))
                                
                                Text("Playing translation...")
                                    .font(.headline)
                                    .foregroundColor(Color(red: 0.00, green: 0.60, blue: 0.40))
                            }
                        } else {
                            Text("Tap to speak")
                                .font(.headline)
                                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.50))
                        }
                    }
                    
                    // Transcription Display
                    if !transcribedText.isEmpty || !translatedText.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            if !transcribedText.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    Label("You said:", systemImage: "mic")
                                        .font(.caption)
                                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.50))
                                    
                                    Text(transcribedText)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(red: 0.95, green: 0.98, blue: 0.97))
                                        .cornerRadius(10)
                                }
                            }
                            
                            if !translatedText.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    Label("Translation:", systemImage: "speaker.wave.2")
                                        .font(.caption)
                                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.50))
                                    
                                    Text(translatedText)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(red: 0.00, green: 0.60, blue: 0.40).opacity(0.1))
                                        .cornerRadius(10)
                                    
                                    // Replay button
                                    Button(action: replayTranslation) {
                                        Label("Replay", systemImage: "play.circle")
                                            .font(.caption)
                                    }
                                    .disabled(isPlaying || audioManager.lastAudioData == nil)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                    }
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Mervyn Talks")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showHistory = true }) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: testConnection) {
                        Image(systemName: "wifi")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
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
    
    private func startRecording() {
        transcribedText = ""
        translatedText = ""
        recordingDuration = 0
        
        audioManager.startRecording { success in
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
        
        Task {
            do {
                // 1. Speech to Text
                let transcription = try await audioManager.transcribeAudio(
                    audioURL,
                    language: sourceLanguage
                )
                
                await MainActor.run {
                    self.transcribedText = transcription
                }
                
                // 2. Send to translation API with audio response
                let response = try await translationService.translateWithAudio(
                    text: transcription,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                await MainActor.run {
                    self.translatedText = response.translatedText
                    self.isProcessing = false
                }
                
                // 3. Play the audio response
                if let audioData = response.audioData {
                    playTranslation(audioData)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isProcessing = false
                    
                    // Cancel tracking if translation fails
                    self.usageService.cancelTranslationSession()
                }
            }
        }
    }
    
    private func playTranslation(_ audioData: Data) {
        isPlaying = true
        audioManager.playAudio(audioData) { completed in
            isPlaying = false
        }
    }
    
    private func replayTranslation() {
        if let audioData = audioManager.lastAudioData {
            playTranslation(audioData)
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
    
    private func setupAudio() {
        audioManager.setupSession()
    }
    
    private func requestPermissions() {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone access is required for voice translation"
                    self.showError = true
                }
            }
        }
        
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                DispatchQueue.main.async {
                    self.errorMessage = "Speech recognition access is required"
                    self.showError = true
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
            let isHealthy = await translationService.checkAPIHealth()
            await MainActor.run {
                errorMessage = isHealthy ? "✅ API connection successful" : "❌ API connection failed"
                showError = true
            }
        }
    }
    
    // MARK: - Timer
    
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
        .background(Color(red: 0.95, green: 0.98, blue: 0.97))
        .cornerRadius(8)
    }
}

struct HistoryView: View {
    @StateObject private var translationService = TranslationService.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List(translationService.translationHistory) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(languageName(for: item.sourceLanguage), systemImage: "mic")
                            .font(.caption)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                        
                        Label(languageName(for: item.targetLanguage), systemImage: "speaker.wave.2")
                            .font(.caption)
                        
                        Spacer()
                        
                        if let timestamp = item.timestamp {
                            Text(timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
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
    
    private func languageName(for code: String) -> String {
        Language.name(for: code)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UsageTrackingService.shared)
    }
}