//
//  WatchOS_Redesign_Implementation.swift
//  Universal Translator Watch App
//
//  Comprehensive redesign implementation for Apple Watch interface
//  Addresses all identified UX issues with modern watchOS patterns
//

import SwiftUI
import WatchKit
import WatchConnectivity

// MARK: - Enhanced Language Management

extension Language {
    static let watchOptimizedLanguages: [Language] = [
        // Most common languages first for Digital Crown navigation
        Language(code: "en", name: "English", nativeName: "English", flag: "🇺🇸", isOfflineAvailable: true),
        Language(code: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸", isOfflineAvailable: true),
        Language(code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷"),
        Language(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪"),
        Language(code: "zh", name: "Chinese", nativeName: "中文", flag: "🇨🇳"),
        Language(code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵"),
        Language(code: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
        Language(code: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦"),
        Language(code: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
        Language(code: "pt", name: "Portuguese", nativeName: "Português", flag: "🇧🇷"),
        Language(code: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹"),
        Language(code: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳"),
        Language(code: "nl", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱"),
        Language(code: "sv", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪"),
        Language(code: "da", name: "Danish", nativeName: "Dansk", flag: "🇩🇰"),
        Language(code: "no", name: "Norwegian", nativeName: "Norsk", flag: "🇳🇴"),
        Language(code: "fi", name: "Finnish", nativeName: "Suomi", flag: "🇫🇮"),
        Language(code: "pl", name: "Polish", nativeName: "Polski", flag: "🇵🇱"),
        Language(code: "tr", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷"),
        Language(code: "th", name: "Thai", nativeName: "ไทย", flag: "🇹🇭"),
        Language(code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳"),
        Language(code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩")
    ]
    
    var shortName: String {
        // Abbreviated names for Watch display
        switch code {
        case "en": return "EN"
        case "es": return "ES"
        case "fr": return "FR"
        case "de": return "DE"
        case "zh": return "中文"
        case "ja": return "日本"
        case "ko": return "한국"
        case "ar": return "عربي"
        case "ru": return "RU"
        case "pt": return "PT"
        case "it": return "IT"
        case "hi": return "हिं"
        default: return code.uppercased()
        }
    }
}

// MARK: - Watch App State Management

enum WatchAppState: Equatable {
    case idle
    case languageSelection(type: LanguageSelectionType)
    case recording(liveTranscription: String, amplitude: CGFloat)
    case processing(progress: Double)
    case displayingResult(TranslationResult)
    case error(String)
}

enum LanguageSelectionType {
    case source
    case target
}

struct TranslationResult {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let audioData: Data?
}

// MARK: - Enhanced Watch Content View

struct EnhancedWatchContentView: View {
    @StateObject private var audioManager = WatchAudioManager()
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var languageManager = WatchLanguageManager()
    
    @State private var currentState: WatchAppState = .idle
    @State private var sourceLanguage = "en"
    @State private var targetLanguage = "es"
    @State private var lastTranslationResult: TranslationResult?
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 8) {
                    switch currentState {
                    case .idle:
                        idleStateView
                    case .languageSelection(let type):
                        DigitalCrownLanguagePicker(
                            selectedLanguage: binding(for: type),
                            languages: Language.watchOptimizedLanguages,
                            onDismiss: { currentState = .idle }
                        )
                    case .recording(let transcription, let amplitude):
                        LiveRecordingView(
                            transcription: transcription,
                            amplitude: amplitude,
                            onStop: stopRecording
                        )
                    case .processing(let progress):
                        ProcessingView(progress: progress)
                    case .displayingResult(let result):
                        TranslationResultView(
                            result: result,
                            onReplay: replayTranslation,
                            onNewRecording: startNewRecording
                        )
                    case .error(let message):
                        ErrorView(
                            message: message,
                            onRetry: retryLastAction,
                            onDismiss: { currentState = .idle }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Translator")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear(perform: setupView)
        .onChange(of: connectivityManager.lastResponse) { response in
            handleTranslationResponse(response)
        }
    }
    
    // MARK: - State-Specific Views
    
    private var idleStateView: some View {
        VStack(spacing: 12) {
            // Compact language selector with sync indicator
            CompactLanguageSelector(
                sourceLanguage: $sourceLanguage,
                targetLanguage: $targetLanguage,
                onSourceTap: { currentState = .languageSelection(type: .source) },
                onTargetTap: { currentState = .languageSelection(type: .target) },
                onSwap: swapLanguages,
                isSynced: connectivityManager.isReachable
            )
            
            // Large recording button
            LargeRecordingButton(
                isEnabled: connectivityManager.isReachable && connectivityManager.creditsRemaining > 0,
                onTap: startRecording
            )
            
            // Connection & credit status
            StatusIndicatorView(
                isConnected: connectivityManager.isReachable,
                creditsRemaining: connectivityManager.creditsRemaining,
                showDetailedStatus: false
            )
            
            // Replay button if previous translation exists
            if lastTranslationResult != nil {
                Button("Replay Last") { replayTranslation() }
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - Actions & Helpers
    
    private func binding(for type: LanguageSelectionType) -> Binding<String> {
        switch type {
        case .source: return $sourceLanguage
        case .target: return $targetLanguage
        }
    }
    
    private func setupView() {
        connectivityManager.activate()
        languageManager.loadRecentLanguages()
        // Sync with iPhone language settings
        if connectivityManager.isReachable {
            connectivityManager.syncLanguages()
        }
    }
    
    private func startRecording() {
        guard connectivityManager.isReachable else {
            currentState = .error("iPhone not connected")
            return
        }
        
        currentState = .recording(liveTranscription: "", amplitude: 0)
        audioManager.startRecordingWithLiveTranscription { transcription, amplitude in
            currentState = .recording(liveTranscription: transcription, amplitude: amplitude)
        }
    }
    
    private func stopRecording() {
        audioManager.stopRecording { audioURL in
            if let audioURL = audioURL {
                sendTranslationRequest(audioURL)
            } else {
                currentState = .error("Recording failed")
            }
        }
    }
    
    private func sendTranslationRequest(_ audioURL: URL) {
        currentState = .processing(progress: 0)
        
        let request = TranslationRequest(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            audioFileURL: audioURL
        )
        
        connectivityManager.sendTranslationRequest(request) { success in
            if !success {
                currentState = .error("Failed to send request")
            }
            // Processing state continues until response arrives
        }
    }
    
    private func handleTranslationResponse(_ response: TranslationResponse?) {
        guard let response = response else {
            currentState = .error("No response received")
            return
        }
        
        if let error = response.error {
            currentState = .error(error)
        } else {
            let result = TranslationResult(
                originalText: response.originalText,
                translatedText: response.translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                audioData: response.audioData
            )
            lastTranslationResult = result
            currentState = .displayingResult(result)
            
            // Auto-play translation if audio available
            if let audioData = response.audioData {
                audioManager.playAudio(audioData) { _ in }
            }
        }
    }
    
    private func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
        languageManager.recordLanguageUsage(source: sourceLanguage, target: targetLanguage)
    }
    
    private func replayTranslation() {
        guard let result = lastTranslationResult,
              let audioData = result.audioData else { return }
        audioManager.playAudio(audioData) { _ in }
    }
    
    private func startNewRecording() {
        currentState = .idle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            startRecording()
        }
    }
    
    private func retryLastAction() {
        // Retry based on current context
        startRecording()
    }
}

// MARK: - Digital Crown Language Picker

struct DigitalCrownLanguagePicker: View {
    @Binding var selectedLanguage: String
    let languages: [Language]
    let onDismiss: () -> Void
    
    @State private var selectedIndex: Double = 0
    @State private var searchText = ""
    
    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return languages
        }
        return languages.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.nativeName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Current selection display
            VStack(spacing: 4) {
                if let currentLanguage = filteredLanguages.first(where: { $0.code == selectedLanguage }) {
                    Text(currentLanguage.flag)
                        .font(.largeTitle)
                    Text(currentLanguage.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(currentLanguage.nativeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            // Scrollable language list
            ScrollViewReader { proxy in
                List(Array(filteredLanguages.enumerated()), id: \.element.code) { index, language in
                    LanguageRow(
                        language: language,
                        isSelected: language.code == selectedLanguage,
                        isCompact: true
                    )
                    .onTapGesture {
                        selectedLanguage = language.code
                        WKInterfaceDevice.current().play(.click)
                        onDismiss()
                    }
                    .id(language.code)
                }
                .digitalCrownRotation(
                    $selectedIndex,
                    from: 0,
                    through: Double(max(0, filteredLanguages.count - 1)),
                    by: 1,
                    sensitivity: .low,
                    isContinuous: false
                )
                .onChange(of: selectedIndex) { newValue in
                    let index = Int(newValue.rounded())
                    if index < filteredLanguages.count {
                        selectedLanguage = filteredLanguages[index].code
                        proxy.scrollTo(selectedLanguage, anchor: .center)
                    }
                }
            }
            
            // Done button
            Button("Done") {
                onDismiss()
            }
            .font(.headline)
            .foregroundColor(.blue)
        }
        .onAppear {
            // Set initial index
            if let index = filteredLanguages.firstIndex(where: { $0.code == selectedLanguage }) {
                selectedIndex = Double(index)
            }
        }
    }
}

// MARK: - Compact Language Selector for Idle State

struct CompactLanguageSelector: View {
    @Binding var sourceLanguage: String
    @Binding var targetLanguage: String
    let onSourceTap: () -> Void
    let onTargetTap: () -> Void
    let onSwap: () -> Void
    let isSynced: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Source language
            LanguageChip(
                language: sourceLanguage,
                isSource: true,
                onTap: onSourceTap
            )
            
            // Swap button
            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Target language
            LanguageChip(
                language: targetLanguage,
                isSource: false,
                onTap: onTargetTap
            )
            
            // Sync indicator
            if isSynced {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct LanguageChip: View {
    let language: String
    let isSource: Bool
    let onTap: () -> Void
    
    private var languageInfo: Language? {
        Language.watchOptimizedLanguages.first { $0.code == language }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(isSource ? "From" : "To")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Text(languageInfo?.flag ?? "🌐")
                        .font(.caption)
                    Text(languageInfo?.shortName ?? language.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Live Recording View with Transcription

struct LiveRecordingView: View {
    let transcription: String
    let amplitude: CGFloat
    let onStop: () -> Void
    
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 12) {
            // Recording timer
            Text(timeString(from: recordingTime))
                .font(.caption.monospacedDigit())
                .foregroundColor(.orange)
            
            // Live waveform visualization
            WaveformVisualization(amplitude: amplitude)
                .frame(height: 40)
            
            // Live transcription display
            ScrollView {
                Text(transcription.isEmpty ? "Listening..." : transcription)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(transcription.isEmpty ? .secondary : .primary)
                    .padding(.horizontal, 8)
            }
            .frame(maxHeight: 60)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            
            // Stop recording button
            Button(action: onStop) {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 60, height: 60)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 20, height: 20)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Waveform Visualization

struct WaveformVisualization: View {
    let amplitude: CGFloat
    @State private var waveformData: [CGFloat] = Array(repeating: 0, count: 20)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<waveformData.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 3, height: max(2, waveformData[index] * 30))
                    .animation(.easeInOut(duration: 0.1), value: waveformData[index])
            }
        }
        .onChange(of: amplitude) { newAmplitude in
            updateWaveform(with: newAmplitude)
        }
    }
    
    private func updateWaveform(with newAmplitude: CGFloat) {
        waveformData.removeFirst()
        waveformData.append(newAmplitude)
    }
}

// MARK: - Translation Result Display

struct TranslationResultView: View {
    let result: TranslationResult
    let onReplay: () -> Void
    let onNewRecording: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Source text (compact)
                if !result.originalText.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(Language.watchOptimizedLanguages.first { $0.code == result.sourceLanguage }?.flag ?? "🌐")
                            Text(Language.watchOptimizedLanguages.first { $0.code == result.sourceLanguage }?.shortName ?? result.sourceLanguage)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(result.originalText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                }
                
                // Translated text (prominent)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(Language.watchOptimizedLanguages.first { $0.code == result.targetLanguage }?.flag ?? "🌐")
                        Text(Language.watchOptimizedLanguages.first { $0.code == result.targetLanguage }?.shortName ?? result.targetLanguage)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    Text(result.translatedText)
                        .font(.callout.weight(.semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue.opacity(0.3), lineWidth: 1)
                )
                
                // Action buttons
                HStack(spacing: 16) {
                    if result.audioData != nil {
                        Button("Replay") {
                            onReplay()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.blue)
                    }
                    
                    Button("New") {
                        onNewRecording()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
                }
            }
        }
    }
}

// MARK: - Processing View

struct ProcessingView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Translating...")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if progress > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 120)
            }
        }
    }
}

// MARK: - Large Recording Button

struct LargeRecordingButton: View {
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isEnabled ? .blue : .gray)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "mic.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1.0 : 0.9)
        .opacity(isEnabled ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - Enhanced Audio Manager

extension WatchAudioManager {
    func startRecordingWithLiveTranscription(onUpdate: @escaping (String, CGFloat) -> Void) {
        // Implementation for live transcription during recording
        // This would integrate with speech recognition for real-time feedback
    }
}

// MARK: - Watch Language Manager

class WatchLanguageManager: ObservableObject {
    @Published var recentLanguagePairs: [(source: String, target: String)] = []
    
    func loadRecentLanguages() {
        // Load from UserDefaults or sync with iPhone
    }
    
    func recordLanguageUsage(source: String, target: String) {
        // Track usage for smart suggestions
    }
    
    func getRecentLanguages() -> [String] {
        // Return frequently used languages for top of picker
        return []
    }
}