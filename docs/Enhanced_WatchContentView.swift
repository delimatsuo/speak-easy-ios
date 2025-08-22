import SwiftUI
import WatchKit
import Combine

// MARK: - Enhanced Apple Watch Content View with Live Transcription and Digital Crown Language Selection

struct EnhancedWatchContentView: View {
    @StateObject private var viewModel = EnhancedWatchTranslationViewModel()
    @State private var crownValue: Double = 0
    @State private var selectedLanguageIndex: Int = 0
    @State private var showingLanguageList = false
    @State private var recordingTimer: Timer?
    @State private var silenceTimer: Timer?
    
    private let hapticFeedback = WKHapticType.success
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                // Header with time and app title
                headerView
                
                // Language selection section
                languageSelectionView
                
                // Main content based on current state
                Group {
                    switch viewModel.currentState {
                    case .idle:
                        idleStateView
                    case .recording:
                        recordingStateView
                    case .processing:
                        processingStateView
                    case .completed:
                        completedStateView
                    case .error:
                        errorStateView
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentState)
                
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 8)
            .background(Color.black)
            .ignoresSafeArea()
            .focusable(true)
            .digitalCrownRotation($crownValue, from: 0, through: Double(viewModel.availableLanguages.count - 1), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            .onChange(of: crownValue) { _, newValue in
                handleCrownRotation(newValue)
            }
            .onAppear {
                viewModel.initializeWatchSession()
            }
        }
    }
    
    // MARK: - Header View
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
            
            // Connection indicator
            Circle()
                .fill(viewModel.isConnectedToPhone ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
        }
        .padding(.top, 2)
    }
    
    // MARK: - Language Selection View
    private var languageSelectionView: some View {
        HStack(spacing: 8) {
            // From language
            Button(action: {
                showingLanguageList = true
                viewModel.isSelectingSourceLanguage = true
            }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("From")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(viewModel.sourceLanguage.displayName)
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
            .accessibilityLabel("Select source language: \(viewModel.sourceLanguage.displayName)")
            
            // Swap button
            Button(action: {
                viewModel.swapLanguages()
                WKInterfaceDevice.current().play(hapticFeedback)
            }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("Swap languages")
            
            // To language
            Button(action: {
                showingLanguageList = true
                viewModel.isSelectingSourceLanguage = false
            }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(viewModel.targetLanguage.displayName)
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
            .accessibilityLabel("Select target language: \(viewModel.targetLanguage.displayName)")
        }
        .sheet(isPresented: $showingLanguageList) {
            LanguageSelectionView(
                languages: viewModel.availableLanguages,
                selectedLanguage: viewModel.isSelectingSourceLanguage ? 
                    $viewModel.sourceLanguage : $viewModel.targetLanguage,
                isPresented: $showingLanguageList
            )
        }
    }
    
    // MARK: - Idle State View
    private var idleStateView: some View {
        VStack(spacing: 12) {
            // Record button with enhanced visual design
            Button(action: startRecording) {
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
            
            // Recent translations (if any)
            if !viewModel.recentTranslations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    ForEach(viewModel.recentTranslations.prefix(2), id: \.id) { translation in
                        RecentTranslationRow(translation: translation) {
                            viewModel.playTranslation(translation)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Recording State View  
    private var recordingStateView: some View {
        VStack(spacing: 8) {
            // Recording indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .opacity(viewModel.isRecording ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isRecording)
                
                Text("Recording...")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Spacer()
                
                Text(formatTime(viewModel.recordingDuration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Live transcription display
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if !viewModel.liveTranscription.isEmpty {
                        Text("You're saying:")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Text(viewModel.liveTranscription)
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
            
            // Audio waveform visualization
            WaveformView(audioLevels: viewModel.audioLevels)
                .frame(height: 30)
            
            // Auto-stop countdown (if applicable)
            if viewModel.silenceCountdown > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    Text("Auto-stop in \(viewModel.silenceCountdown)s")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            // Stop button
            Button(action: stopRecording) {
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
    
    // MARK: - Processing State View
    private var processingStateView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.2)
            
            Text("Translating...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            if !viewModel.recordedText.isEmpty {
                Text("✓ \(viewModel.recordedText)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Completed State View
    private var completedStateView: some View {
        VStack(spacing: 8) {
            // Source text
            VStack(alignment: .leading, spacing: 4) {
                Text("You said:")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Text(viewModel.recordedText)
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
                
                Text(viewModel.translatedText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Play translation audio
                Button(action: {
                    viewModel.playTranslationAudio()
                }) {
                    Image(systemName: viewModel.isPlayingAudio ? "speaker.wave.2.fill" : "speaker.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                        )
                }
                .accessibilityLabel(viewModel.isPlayingAudio ? "Stop audio" : "Play translation audio")
                
                // New translation
                Button(action: {
                    viewModel.resetForNewTranslation()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                        Text("New")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.blue)
                    )
                }
                .accessibilityLabel("Start new translation")
            }
        }
    }
    
    // MARK: - Error State View
    private var errorStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)
            
            Text(viewModel.errorMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Retry and cancel buttons
            HStack(spacing: 8) {
                Button("Cancel") {
                    viewModel.resetForNewTranslation()
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
                    viewModel.retryTranslation()
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
    
    // MARK: - Helper Methods
    private func handleCrownRotation(_ value: Double) {
        let newIndex = Int(value.rounded())
        if newIndex != selectedLanguageIndex && newIndex >= 0 && newIndex < viewModel.availableLanguages.count {
            selectedLanguageIndex = newIndex
            WKInterfaceDevice.current().play(.click)
        }
    }
    
    private func startRecording() {
        viewModel.startRecording()
        WKInterfaceDevice.current().play(hapticFeedback)
    }
    
    private func stopRecording() {
        viewModel.stopRecording()
        WKInterfaceDevice.current().play(hapticFeedback)
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
}

// MARK: - Language Selection View
struct LanguageSelectionView: View {
    let languages: [WatchLanguage]
    @Binding var selectedLanguage: WatchLanguage
    @Binding var isPresented: Bool
    
    @State private var searchText = ""
    @State private var crownValue: Double = 0
    
    private var filteredLanguages: [WatchLanguage] {
        if searchText.isEmpty {
            return languages
        } else {
            return languages.filter { $0.displayName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Recent languages section
                if !recentLanguages.isEmpty {
                    Section("Recent") {
                        ForEach(recentLanguages, id: \.code) { language in
                            LanguageRow(
                                language: language,
                                isSelected: language.code == selectedLanguage.code
                            ) {
                                selectedLanguage = language
                                isPresented = false
                            }
                        }
                    }
                }
                
                // All languages section
                Section("All Languages") {
                    ForEach(filteredLanguages, id: \.code) { language in
                        LanguageRow(
                            language: language,
                            isSelected: language.code == selectedLanguage.code
                        ) {
                            selectedLanguage = language
                            isPresented = false
                        }
                    }
                }
            }
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.inline)
            .focusable(true)
            .digitalCrownRotation($crownValue, from: 0, through: Double(max(0, filteredLanguages.count - 1)), by: 1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private var recentLanguages: [WatchLanguage] {
        // Return recently used languages (would be fetched from UserDefaults or similar)
        []
    }
}

// MARK: - Language Row Component
struct LanguageRow: View {
    let language: WatchLanguage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    if let nativeName = language.nativeName, nativeName != language.displayName {
                        Text(nativeName)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if isSelected {
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

// MARK: - Recent Translation Row
struct RecentTranslationRow: View {
    let translation: RecentTranslation
    let onPlay: () -> Void
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(translation.originalText)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Text(translation.translatedText)
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "speaker.2.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Waveform Visualization
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

// MARK: - Supporting Data Models

enum WatchTranslationState {
    case idle
    case recording
    case processing
    case completed
    case error
}

struct WatchLanguage: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let displayName: String
    let nativeName: String?
    
    static func == (lhs: WatchLanguage, rhs: WatchLanguage) -> Bool {
        lhs.code == rhs.code
    }
}

struct RecentTranslation: Identifiable {
    let id = UUID()
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let timestamp: Date
}

// MARK: - Enhanced View Model (Stub)
class EnhancedWatchTranslationViewModel: ObservableObject {
    @Published var currentState: WatchTranslationState = .idle
    @Published var sourceLanguage = WatchLanguage(code: "en", displayName: "English", nativeName: nil)
    @Published var targetLanguage = WatchLanguage(code: "es", displayName: "Spanish", nativeName: "Español")
    @Published var liveTranscription = ""
    @Published var recordedText = ""
    @Published var translatedText = ""
    @Published var errorMessage = ""
    @Published var isRecording = false
    @Published var isPlayingAudio = false
    @Published var recordingDuration = 0
    @Published var silenceCountdown = 0
    @Published var audioLevels: [Float] = Array(repeating: 0.1, count: 20)
    @Published var recentTranslations: [RecentTranslation] = []
    @Published var isConnectedToPhone = true
    @Published var isSelectingSourceLanguage = true
    
    let availableLanguages = [
        WatchLanguage(code: "en", displayName: "English", nativeName: nil),
        WatchLanguage(code: "es", displayName: "Spanish", nativeName: "Español"),
        WatchLanguage(code: "fr", displayName: "French", nativeName: "Français"),
        WatchLanguage(code: "de", displayName: "German", nativeName: "Deutsch"),
        WatchLanguage(code: "it", displayName: "Italian", nativeName: "Italiano"),
        WatchLanguage(code: "pt", displayName: "Portuguese", nativeName: "Português"),
        WatchLanguage(code: "ja", displayName: "Japanese", nativeName: "日本語"),
        WatchLanguage(code: "ko", displayName: "Korean", nativeName: "한국어"),
        WatchLanguage(code: "zh", displayName: "Chinese", nativeName: "中文"),
        WatchLanguage(code: "ar", displayName: "Arabic", nativeName: "العربية")
        // Add more languages as needed
    ]
    
    func initializeWatchSession() {
        // Initialize WatchConnectivity session
    }
    
    func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
    }
    
    func startRecording() {
        currentState = .recording
        isRecording = true
        recordingDuration = 0
        liveTranscription = ""
        
        // Start recording logic here
        startRecordingTimer()
    }
    
    func stopRecording() {
        currentState = .processing
        isRecording = false
        
        // Process the recording
        processRecording()
    }
    
    func resetForNewTranslation() {
        currentState = .idle
        liveTranscription = ""
        recordedText = ""
        translatedText = ""
        errorMessage = ""
        recordingDuration = 0
        silenceCountdown = 0
    }
    
    func retryTranslation() {
        if !recordedText.isEmpty {
            currentState = .processing
            processRecording()
        }
    }
    
    func playTranslation(_ translation: RecentTranslation) {
        // Play the recent translation audio
    }
    
    func playTranslationAudio() {
        isPlayingAudio.toggle()
        // Implement audio playback
    }
    
    private func startRecordingTimer() {
        // Timer for recording duration and auto-stop logic
    }
    
    private func processRecording() {
        // Send to iPhone for processing via WatchConnectivity
        // Handle response and update UI accordingly
        
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.currentState = .completed
            self.recordedText = "Hello, how are you?"
            self.translatedText = "Hola, ¿cómo estás?"
        }
    }
}

#Preview {
    EnhancedWatchContentView()
}