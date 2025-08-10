//
//  ContentView.swift
//  Mervyn Talks
//
//  REDESIGNED: Professional layout with proper proportions
//

import SwiftUI
import AVFoundation
import Speech
import Firebase
import UIKit
import FirebaseFirestore
import StoreKit

// Distinguishes which language picker is active for the sheet
private enum LanguagePickerType: Identifiable {
    case source
    case target
    var id: String { self == .source ? "source" : "target" }
}

struct ContentView: View {
    @StateObject private var auth = AuthViewModel.shared
    @StateObject private var audioManager = AudioManager()
    @StateObject private var translationService = TranslationService.shared
    @StateObject private var usageService = UsageTrackingService.shared
    @ObservedObject private var credits = CreditsManager.shared
    
    @State private var sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "en"
    @State private var targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "es"
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var isPlaying = false
    @State private var transcribedText = ""
    @State private var translatedText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var availableLanguages: [Language] = Language.defaultLanguages
    @State private var showHistory = false
    @State private var recordingTimer: Timer?
    @State private var recordingDuration = 0
    @State private var processingStartTime: Date?
    @State private var translationTask: Task<Void, Never>?
    @State private var showPurchaseSheet = false
    @State private var showedSixtySecondReminder = false
    @State private var showProfile = false
    @State private var activeLanguagePicker: LanguagePickerType?
    
    var body: some View {
        ZStack {
            if !auth.isSignedIn {
                SignInView()
            } else {
                NavigationView {
            ScrollView {
                VStack(spacing: DesignConstants.Layout.contentSpacing) {
                    // Centered hero header replacing the default large nav title
                    HeroHeader(
                        title: NSLocalizedString("app_name", comment: "App name displayed in header"),
                        subtitle: NSLocalizedString("app_subtitle", comment: "App subtitle describing main functionality"),
                        onHistory: nil,
                        onProfile: { showProfile = true },
                        style: .fullBleed,
                        remainingSeconds: credits.remainingSeconds
                    )

                    // Optional: remove external credits pill since it's in hero now
                    
                    // Language selector cards
                    LanguageCardsSelector(
                        source: $sourceLanguage,
                        target: $targetLanguage,
                        languages: availableLanguages,
                        onSwap: swapLanguages,
                        onTapSource: { showLanguagePicker(isSource: true) },
                        onTapTarget: { showLanguagePicker(isSource: false) }
                    )
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    // Microphone Button Section (PROPERLY SIZED!)
                    VStack(spacing: DesignConstants.Layout.cardSpacing) {
                        ModernMicrophoneButton(
                            isRecording: $isRecording,
                            isProcessing: isProcessing,
                            isPlaying: isPlaying,
                            action: toggleRecording
                        )
                        .padding(.vertical, 20)
                        .disabled(!isRecording && !isProcessing && !isPlaying && credits.remainingSeconds == 0)
                        
                        // Status Indicator
                        if isRecording || isProcessing || isPlaying {
                            StatusIndicator(
                                isRecording: isRecording,
                                isProcessing: isProcessing,
                                isPlaying: isPlaying,
                                recordingDuration: recordingDuration,
                                processingStartTime: processingStartTime,
                                onCancel: cancelTranslation
                            )
                        } else {
                            Text(NSLocalizedString("tap_to_speak", comment: "Instruction text shown when app is ready for voice input"))
                                .font(.system(size: DesignConstants.Typography.statusTitleSize, 
                                            weight: DesignConstants.Typography.statusTitleWeight))
                                .foregroundColor(.speakEasyTextSecondary)
                        }

                        if credits.remainingSeconds == 60 && !showedSixtySecondReminder {
                            VStack(spacing: 6) {
                                Text(NSLocalizedString("one_minute_left_warning", comment: "Warning message when user has only one minute of credits remaining"))
                                    .font(.subheadline)
                                    .foregroundColor(.speakEasyTextPrimary)
                                Button(NSLocalizedString("buy_minutes", comment: "Button text to purchase more translation minutes")) { showPurchaseSheet = true }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.borderedProminent)
                            }
                            .padding()
                            .background(Color.speakEasySecondaryBackground)
                            .cornerRadius(10)
                            .onAppear { showedSixtySecondReminder = true }
                        }
                    }
                    
                    // Conversation bubbles
                    ConversationBubblesView(
                        sourceText: transcribedText,
                        targetText: translatedText,
                        onPlay: { replayTranslation() }
                    )
                    .transition(.opacity)
                    
                    Spacer(minLength: 30)
                }
            }
            .background(Color.speakEasyBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            // History removed to comply with no-conversation-retention policy
            .sheet(isPresented: $showPurchaseSheet) {
                PurchaseSheet()
            }
            .sheet(item: $activeLanguagePicker) { kind in
                LanguagePickerSheet(
                    selectedLanguage: kind == .source ? $sourceLanguage : $targetLanguage,
                    languages: availableLanguages,
                    title: kind == .source ? NSLocalizedString("speak_in", comment: "Title for source language picker") : NSLocalizedString("translate_to", comment: "Title for target language picker"),
                    isPresented: Binding(
                        get: { activeLanguagePicker != nil },
                        set: { newValue in if !newValue { activeLanguagePicker = nil } }
                    )
                )
                .onDisappear {
                    // Save preferences when language picker closes
                    saveLanguagePreferences()
                }
            }
            .sheet(isPresented: $showProfile) { ProfileView() }
            .overlay(alignment: .bottom) {
                if credits.remainingSeconds <= 60 && credits.remainingSeconds > 0 {
                    LowBalanceToast(remainingSeconds: credits.remainingSeconds) {
                        showPurchaseSheet = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .alert(NSLocalizedString("error", comment: "Alert title for error messages"), isPresented: $showError) {
                Button(NSLocalizedString("ok", comment: "OK button text")) {
                    resetUIState()
                }
                if !errorMessage.contains("✅") {
                    Button(NSLocalizedString("retry", comment: "Retry button text")) {
                        retryLastTranslation()
                    }
                }
            } message: {
                Text(errorMessage)
                }
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
        .onAppear {
            setupAudio()
            loadLanguages()
            requestPermissions()
            // Sync initial language preferences with Watch
            saveLanguagePreferences()
            NotificationCenter.default.addObserver(forName: .init("ShowPurchaseSheet"), object: nil, queue: .main) { _ in
                showPurchaseSheet = true
            }
        }
    }
    private func showLanguagePicker(isSource: Bool) {
        activeLanguagePicker = isSource ? .source : .target
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            guard credits.canStartTranslation() else {
                // No credits: prompt purchase
                showPurchaseSheet = true
                return
            }
            startRecording()
        }
        
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
        credits.setSessionStarted()
        
        // First check if microphone permission is granted
        let micPermission = AVAudioSession.sharedInstance().recordPermission
        if micPermission != .granted {
            errorMessage = NSLocalizedString("microphone_permission_required", comment: "Error message when microphone permission is not granted")
            showError = true
            return
        }
        
        Task {
            let success = await audioManager.startRecordingAsync()
            if success {
                isRecording = true
                startRecordingTimer()
                print("✅ Recording started successfully in UI")
            } else {
                credits.setSessionStoppedAndRoundUp() // Refund the credits if recording failed
                errorMessage = NSLocalizedString("unable_to_start_recording", comment: "Error message when recording fails to start")
                showError = true
                print("❌ Recording failed to start in UI")
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        stopRecordingTimer()
        credits.setSessionStoppedAndRoundUp()
        
        audioManager.stopRecording { audioURL in
            if let audioURL = audioURL {
                processRecording(audioURL)
            } else {
                errorMessage = NSLocalizedString("failed_to_save_recording", comment: "Error message when recording cannot be saved")
                showError = true
            }
        }
    }
    
    private func processRecording(_ audioURL: URL) {
        isProcessing = true
        processingStartTime = Date()
        
        translationTask = Task {
            do {
                var transcription: String
                
                // Check if local STT is available
                let locale = Locale(identifier: sourceLanguage)
                let recognizer = SFSpeechRecognizer(locale: locale)
                let authorized = SFSpeechRecognizer.authorizationStatus() == .authorized
                let available = recognizer?.isAvailable ?? false
                
                print("📱 STT Status - Authorized: \(authorized), Available: \(available), Language: \(sourceLanguage)")
                
                if authorized && available {
                    do {
                        print("🎙️ Using local STT for language: \(sourceLanguage)")
                        transcription = try await audioManager.transcribeAudio(audioURL, language: sourceLanguage)
                        print("✅ Local STT successful: \"\(transcription.prefix(50))...\"")
                    } catch {
                        let nsError = error as NSError
                        print("⚠️ Local STT failed - Domain: \(nsError.domain), Code: \(nsError.code), Error: \(error.localizedDescription)")
                        print("📡 Falling back to server STT...")
                        transcription = try await translationService.remoteSpeechToText(audioURL: audioURL, language: sourceLanguage)
                        print("✅ Server STT fallback successful")
                    }
                } else {
                    print("📡 Using server STT (local not available - Auth: \(authorized), Avail: \(available))")
                    transcription = try await translationService.remoteSpeechToText(audioURL: audioURL, language: sourceLanguage)
                }
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.transcribedText = transcription
                }
                
                print("📤 Sending transcribed text for translation: \"\(transcription.prefix(50))...\"")
                print("   From: \(sourceLanguage) To: \(targetLanguage)")
                
                let response = try await translationService.translateWithAudio(
                    text: transcription,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                print("✅ Translation successful!")
                
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.translatedText = response.translatedText
                    self.isProcessing = false
                }
                
                if let audioData = response.audioData {
                    await MainActor.run {
                        self.isProcessing = false
                    }
                    playTranslation(audioData)
                }
                
            } catch is CancellationError {
                await MainActor.run {
                    self.isProcessing = false
                    self.processingStartTime = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = formatErrorMessage(error)
                    self.showError = true
                    self.isProcessing = false
                    self.processingStartTime = nil
                    self.usageService.cancelTranslationSession()
                }
            }
        }
    }
    
    private func formatErrorMessage(_ error: Error) -> String {
        if let translationError = error as? TranslationError {
            return translationError.localizedDescription
        }
        return String(format: NSLocalizedString("translation_failed_format", comment: "Generic translation error message format"), error.localizedDescription)
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
    
    private func swapLanguages() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
        
        // Save to UserDefaults and sync with Watch
        saveLanguagePreferences()
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
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                let granted = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                
                await MainActor.run {
                    if !granted {
                        self.errorMessage = NSLocalizedString("microphone_required_for_translation", comment: "Error message explaining microphone is needed for translation")
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
                        self.errorMessage = NSLocalizedString("speech_recognition_required", comment: "Error message when speech recognition permission is not granted")
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
    
    private func cancelTranslation() {
        translationTask?.cancel()
        translationTask = nil
        translationService.cancelCurrentTranslation()
        isProcessing = false
        processingStartTime = nil
        usageService.cancelTranslationSession()
    }
    
    private func saveLanguagePreferences() {
        UserDefaults.standard.set(sourceLanguage, forKey: "sourceLanguage")
        UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage")
        
        // Sync with Watch if connected
        WatchSessionManager.shared.syncLanguages(source: sourceLanguage, target: targetLanguage)
    }
    
    private func resetUIState() {
        isRecording = false
        isProcessing = false
        isPlaying = false
        processingStartTime = nil
        translationTask?.cancel()
        translationTask = nil
        stopRecordingTimer()
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
                } catch {
                    await MainActor.run {
                        self.errorMessage = String(format: NSLocalizedString("retry_failed_format", comment: "Error message when retry operation fails"), self.formatErrorMessage(error))
                        self.showError = true
                        self.isProcessing = false
                        self.processingStartTime = nil
                    }
                }
            }
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // Deduct credits per elapsed second
            CreditsManager.shared.deduct(seconds: 1)
            recordingDuration += 1
            
            // Stop if out of credits
            if CreditsManager.shared.remainingSeconds <= 0 {
                stopRecording()
                showPurchaseSheet = true
                return
            }
            
            // Safety cap to 60s per recording (existing behavior)
            if recordingDuration >= 60 {
                stopRecording()
            }
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let isRecording: Bool
    let isProcessing: Bool
    let isPlaying: Bool
    let recordingDuration: Int
    let processingStartTime: Date?
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if isRecording {
                Text(NSLocalizedString("listening", comment: "Status text shown while recording user's voice"))
                    .font(.system(size: DesignConstants.Typography.statusTitleSize, 
                                weight: DesignConstants.Typography.statusTitleWeight))
                    .foregroundColor(.speakEasyRecording)
                
                Text(formatDuration(recordingDuration))
                    .font(.system(size: DesignConstants.Typography.statusSubtitleSize, 
                                weight: DesignConstants.Typography.statusSubtitleWeight))
                    .foregroundColor(.speakEasyTextSecondary)
                
            } else if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .speakEasyProcessing))
                    .scaleEffect(1.2)
                
                Text(NSLocalizedString("translating", comment: "Status text shown while processing translation"))
                    .font(.system(size: DesignConstants.Typography.statusTitleSize, 
                                weight: DesignConstants.Typography.statusTitleWeight))
                    .foregroundColor(.speakEasyProcessing)
                
                if let startTime = processingStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    Text(String(format: NSLocalizedString("elapsed_seconds", comment: "Shows elapsed time during processing"), elapsed))
                        .font(.system(size: DesignConstants.Typography.statusSubtitleSize, 
                                    weight: DesignConstants.Typography.statusSubtitleWeight))
                        .foregroundColor(.speakEasyTextSecondary)
                }
                
                Button(NSLocalizedString("cancel", comment: "Button text to cancel current operation")) {
                    onCancel()
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(.top, 5)
                
            } else if isPlaying {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.largeTitle)
                    .foregroundColor(.speakEasyPrimary)
                
                Text(NSLocalizedString("playing_translation", comment: "Status text shown while playing translated audio"))
                    .font(.system(size: DesignConstants.Typography.statusTitleSize, 
                                weight: DesignConstants.Typography.statusTitleWeight))
                    .foregroundColor(.speakEasyPrimary)
            }
        }
        .frame(minHeight: DesignConstants.Sizing.statusIndicatorHeight)
        .animation(DesignConstants.Animations.gentle, value: isRecording)
        .animation(DesignConstants.Animations.gentle, value: isProcessing)
        .animation(DesignConstants.Animations.gentle, value: isPlaying)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - History View

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
                        .foregroundColor(.speakEasyTextSecondary)
                        .lineLimit(2)
                    
                    if item.hasAudio {
                        Button(action: {
                            if let audioURL = item.audioURL {
                                AudioManager.shared.playAudioFromURL(audioURL)
                            }
                        }) {
                            Label(NSLocalizedString("play", comment: "Button text to play audio"), systemImage: "play.circle")
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle(NSLocalizedString("translation_history", comment: "Title for translation history screen"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Button text to dismiss screen")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UsageTrackingService.shared)
    }
}