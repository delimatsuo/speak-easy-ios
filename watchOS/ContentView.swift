//
//  ContentView.swift
//  UniversalTranslator Watch App
//
//  Main UI for the Watch app
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @StateObject private var audioManager = WatchAudioManager()
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    @State private var currentState: AppState = .idle
    @State private var sourceLanguage = "en"
    @State private var targetLanguage = "es"
    @State private var errorMessage = ""
    @State private var translatedText = ""
    @State private var originalText = ""
    @State private var recordingProgress: Double = 0
    @State private var recordingTimer: Timer?
    
    enum AppState {
        case idle
        case recording
        case sending
        case processing
        case playing
        case error
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Language Selector
                    HStack(spacing: 8) {
                        LanguageButton(language: sourceLanguage, isSource: true)
                            .onTapGesture {
                                // TODO: Show language picker
                            }
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LanguageButton(language: targetLanguage, isSource: false)
                            .onTapGesture {
                                // TODO: Show language picker
                            }
                    }
                    .padding(.horizontal)
                    
                    // Main Recording Button
                    RecordingButton(
                        state: currentState,
                        progress: recordingProgress,
                        action: handleRecordingTap
                    )
                    .frame(height: 100)
                    
                    // Status Display
                    StatusView(
                        state: currentState,
                        errorMessage: errorMessage,
                        translatedText: translatedText,
                        originalText: originalText,
                        creditsRemaining: connectivityManager.creditsRemaining
                    )
                    
                    // Credits Display
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
            .navigationTitle("Translator")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            connectivityManager.activate()
            connectivityManager.requestCreditsUpdate()
        }
        .onChange(of: connectivityManager.lastResponse) { response in
            handleTranslationResponse(response)
        }
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
        guard connectivityManager.creditsRemaining > 0 else {
            errorMessage = "No credits remaining"
            currentState = .error
            return
        }
        
        guard connectivityManager.isReachable else {
            errorMessage = "iPhone not connected"
            currentState = .error
            return
        }
        
        audioManager.startRecording { success in
            if success {
                currentState = .recording
                recordingProgress = 0
                startRecordingTimer()
                WKInterfaceDevice.current().play(.start)
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
        
        connectivityManager.sendTranslationRequest(request) { success in
            if !success {
                errorMessage = "Failed to send to iPhone"
                currentState = .error
            }
        }
    }
    
    private func handleTranslationResponse(_ response: TranslationResponse?) {
        guard let response = response else { return }
        
        if let error = response.error {
            errorMessage = error
            currentState = .error
            WKInterfaceDevice.current().play(.failure)
        } else {
            originalText = response.originalText
            translatedText = response.translatedText
            
            if let audioData = response.audioData {
                playTranslation(audioData)
            } else {
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

// MARK: - Supporting Views

struct LanguageButton: View {
    let language: String
    let isSource: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text(isSource ? "From" : "To")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(languageName(for: language))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func languageName(for code: String) -> String {
        switch code {
        case "en": return "English"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "it": return "Italian"
        case "pt": return "Portuguese"
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "zh": return "Chinese"
        default: return code.uppercased()
        }
    }
}

struct RecordingButton: View {
    let state: ContentView.AppState
    let progress: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Background circle
                Circle()
                    .fill(backgroundColor)
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: 2)
                    )
                
                // Progress ring for recording
                if state == .recording {
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(Color.red, lineWidth: 3)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: progress)
                }
                
                // Icon
                Image(systemName: iconName)
                    .font(.largeTitle)
                    .foregroundColor(iconColor)
                
                // Loading indicator
                if state == .processing || state == .sending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(state == .processing || state == .sending || state == .playing)
    }
    
    private var backgroundColor: Color {
        switch state {
        case .recording: return Color.red.opacity(0.2)
        case .processing, .sending: return Color.blue.opacity(0.2)
        case .playing: return Color.green.opacity(0.2)
        case .error: return Color.red.opacity(0.1)
        default: return Color.blue.opacity(0.2)
        }
    }
    
    private var borderColor: Color {
        switch state {
        case .recording: return .red
        case .processing, .sending: return .blue
        case .playing: return .green
        case .error: return .red
        default: return .blue
        }
    }
    
    private var iconName: String {
        switch state {
        case .recording: return "stop.fill"
        case .playing: return "speaker.wave.3.fill"
        case .error: return "exclamationmark.triangle"
        default: return "mic.fill"
        }
    }
    
    private var iconColor: Color {
        switch state {
        case .recording: return .red
        case .playing: return .green
        case .error: return .red
        default: return .blue
        }
    }
}

struct StatusView: View {
    let state: ContentView.AppState
    let errorMessage: String
    let translatedText: String
    let originalText: String
    let creditsRemaining: Int
    
    var body: some View {
        VStack(spacing: 8) {
            // Status message
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(statusColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Translation results
            if !originalText.isEmpty || !translatedText.isEmpty {
                VStack(spacing: 4) {
                    if !originalText.isEmpty {
                        Text(originalText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    if !translatedText.isEmpty {
                        Text(translatedText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var statusMessage: String {
        switch state {
        case .recording:
            return "Listening..."
        case .sending:
            return "Sending to iPhone..."
        case .processing:
            return "Translating..."
        case .playing:
            return "Playing translation"
        case .error:
            return errorMessage
        default:
            return creditsRemaining > 0 ? "Tap to translate" : "No credits remaining"
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .error: return .red
        case .recording: return .red
        case .processing, .sending: return .blue
        case .playing: return .green
        default: return .secondary
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}