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
fileprivate enum LanguagePickerType: Identifiable {
    case source
    case target
    var id: String { self == .source ? "source" : "target" }
}

struct ContentView: View {
    @StateObject private var auth = AuthViewModel.shared
    @ObservedObject private var audioManager = AudioManager.shared
    @StateObject private var translationService = TranslationService.shared
    @StateObject private var usageService = UsageTrackingService.shared
    @ObservedObject private var credits = CreditsManager.shared
    @ObservedObject private var anonymousCredits = AnonymousCreditsManager.shared
    
    // Anonymous mode state
    @State private var isAnonymousMode = true
    
    @State private var sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "en"
    @State private var targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "es"
    @State private var transcribedText = ""
    @State private var translatedText = ""
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var isPlaying = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPurchaseSheet = false
    @State private var showProfile = false
    @State private var showUsageStats = false
    @State private var showLanguagePicker: LanguagePickerType?
    @State private var recordingDuration = 0
    @State private var recordingTimer: Timer?
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @State private var observer: NSObjectProtocol?
    
    // Computed properties for anonymous/authenticated mode
    private var currentCredits: Int {
        isAnonymousMode ? anonymousCredits.remainingSeconds : credits.remainingSeconds
    }
    
    private var canStartTranslation: Bool {
        isAnonymousMode ? anonymousCredits.canStartTranslation() : credits.canStartTranslation()
    }
    
    var body: some View {
        contentWithOverlay
            .purchaseSheet(isPresented: $showPurchaseSheet, isAnonymousMode: isAnonymousMode)
            .profileSheet(isPresented: $showProfile)
            .usageStatsSheet(isPresented: $showUsageStats)
            .languagePickerSheet(item: $showLanguagePicker, sourceLanguage: $sourceLanguage, targetLanguage: $targetLanguage)
            .errorAlert(isPresented: $showError, message: errorMessage, onRetry: retryLastTranslation)
            .onAppear(perform: setupView)
            .onDisappear(perform: cleanup)
            .onChange(of: sourceLanguage) { newValue in
                UserDefaults.standard.set(newValue, forKey: "sourceLanguage")
            }
            .onChange(of: targetLanguage) { newValue in
                UserDefaults.standard.set(newValue, forKey: "targetLanguage")
            }
            .onChange(of: auth.isSignedIn, perform: handleAuthChange)
    }
    
    private var contentWithOverlay: some View {
        ZStack {
            mainContent
            lowBalanceOverlay
        }
    }
    
    // MARK: - View Components
    
    private var mainContent: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignConstants.Layout.contentSpacing) {
                    headerSection
                    languageSection
                    microphoneSection
                    conversationSection
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, DesignConstants.Layout.screenPadding)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var headerSection: some View {
        HeroHeader(
            title: NSLocalizedString("app_name", comment: "App name displayed in header"),
            subtitle: NSLocalizedString("app_subtitle", comment: "App subtitle describing main functionality"),
            onHistory: nil,
            onProfile: { showProfile = true },
            style: .fullBleed,
            remainingSeconds: isAnonymousMode ? anonymousCredits.remainingSeconds : credits.remainingSeconds
        )
    }
    
    private var languageSection: some View {
        LanguageCardsSelector(
            source: $sourceLanguage,
            target: $targetLanguage,
            languages: Language.defaultLanguages,
            onSwap: swapLanguages,
            onTapSource: { showLanguagePicker = .source },
            onTapTarget: { showLanguagePicker = .target }
        )
    }
    
    private var microphoneSection: some View {
        ModernMicrophoneButton(
            isRecording: $isRecording,
            isProcessing: isProcessing,
            isPlaying: isPlaying,
            action: toggleRecording
        )
        .padding(.vertical, 20)
        .disabled(!isRecording && !isProcessing && !isPlaying && currentCredits == 0)
    }
    
    @ViewBuilder
    private var conversationSection: some View {
        if !transcribedText.isEmpty || !translatedText.isEmpty {
            ConversationBubblesView(
                sourceText: transcribedText,
                targetText: translatedText,
                onPlay: playTranslation
            )
        } else if isRecording {
            // Show live transcription from AudioManager while recording
            if !audioManager.transcribedText.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(audioManager.transcribedText)
                        .font(.body)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var lowBalanceOverlay: some View {
        if currentCredits == 0 {
            // Zero balance - show purchase + Monday reset info
            VStack {
                Spacer()
                ZeroBalanceToast {
                    showPurchaseSheet = true
                }
                .padding(.bottom, 100)
            }
        } else if currentCredits <= 30 && currentCredits > 0 {
            // Low balance warning
            VStack {
                Spacer()
                LowBalanceToast(remainingSeconds: currentCredits) {
                    showPurchaseSheet = true
                }
                .padding(.bottom, 100)
            }
        }
    }
    
    // MARK: - Language Management
    
    private func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
    }
    
    private func setupView() {
        setupAudio()
        loadLanguages()
        requestPermissions()
        
        // Clear any previous conversation text for privacy
        clearConversationText()
        
        // Set up background observer
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            clearConversationText()
            // Clean up audio sessions when app goes to background
            self.audioManager.forceCleanupAllSessions()
        }
        
        // Listen for purchase sheet requests from ProfileView
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowPurchaseSheet"),
            object: nil,
            queue: .main
        ) { _ in
            showPurchaseSheet = true
        }
        
        updateModeBasedOnAuth() // Check if user is already signed in
        
        // Grant starter credits if needed (for new authenticated users)
        Task {
            await credits.grantStarterIfNeededWithDeviceThrottle()
        }
    }
    
    private func cleanup() {
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ShowPurchaseSheet"), object: nil)
    }
    
    private func handleAuthChange(_ isSignedIn: Bool) {
        // Clean up any active audio sessions to prevent crashes
        audioManager.forceCleanupAllSessions()
        
        if isSignedIn && isAnonymousMode {
            // User just signed in - migrate from anonymous to authenticated
            migrateFromAnonymousMode()
        } else if !isSignedIn && !isAnonymousMode {
            // User signed out - switch to anonymous mode
            isAnonymousMode = true
        }
        
        // Clear any UI state that might be stale
        clearConversationText()
        
        // Re-setup audio session after auth change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.audioManager.setupSession()
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            guard canStartTranslation else {
                showPurchaseSheet = true
                return
            }
            startRecording()
        }
        
        // Track usage (removed recordInteraction as it doesn't exist in UsageTrackingService)
    }
    
    private func startRecording() {
        clearConversationText()
        
        // Start background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            self.endBackgroundTask()
        }
        
        isRecording = true
        recordingDuration = 0
        
        // Start the recording timer to deduct credits per second
        startRecordingTimer()
        
        audioManager.startRecording { success in
            Task { @MainActor in
                if success {
                    // Start live transcription using the AudioManager
                    do {
                        try self.audioManager.startLiveTranscription(language: self.sourceLanguage)
                    } catch {
                        print("Failed to start live transcription: \(error)")
                        self.showError("Failed to start speech recognition")
                    }
                } else {
                    self.showError("Failed to start recording")
                    self.isRecording = false
                    self.recordingTimer?.invalidate()
                    self.recordingTimer = nil
                }
            }
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                // Deduct credits per elapsed second from appropriate manager
                if self.isAnonymousMode {
                    self.anonymousCredits.deduct(seconds: 1)
                } else {
                    self.credits.deduct(seconds: 1)
                }
                self.recordingDuration += 1
                
                // Stop if out of credits
                if self.currentCredits <= 0 {
                    self.stopRecording()
                    self.showPurchaseSheet = true
                    return
                }
                
                // Safety cap at 2 minutes
                if self.recordingDuration >= 120 {
                    self.stopRecording()
                    self.showError("Recording stopped at 2-minute limit")
                    return
                }
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Stop live transcription first
        audioManager.stopLiveTranscription()
        
        // Copy the transcribed text from AudioManager
        transcribedText = audioManager.transcribedText
        
        audioManager.stopRecording { _ in }
        
        if !transcribedText.isEmpty {
            translateText()
        } else {
            showError("No speech detected. Please try again.")
        }
        
        endBackgroundTask()
    }
    
    private func translateText() {
        guard !transcribedText.isEmpty else { return }
        
        isProcessing = true
        let translationStartTime = Date()
        
        Task {
            do {
                let result = try await translationService.translateWithAudio(
                    text: transcribedText,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                let translationDuration = Date().timeIntervalSince(translationStartTime)
                print("🚀 Translation completed in \(String(format: "%.2f", translationDuration))s")
                
                await MainActor.run {
                    self.translatedText = result.translatedText
                    self.isProcessing = false
                    
                    // Auto-play the translation
                    if let audioData = result.audioData {
                        self.playAudio(audioData)
                    }
                }
            } catch {
                let translationDuration = Date().timeIntervalSince(translationStartTime)
                print("❌ Translation failed after \(String(format: "%.2f", translationDuration))s: \(error)")
                
                await MainActor.run {
                    self.isProcessing = false
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func playTranslation() {
        guard !translatedText.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            do {
                let result = try await translationService.translateWithAudio(
                    text: translatedText,
                    from: targetLanguage,
                    to: targetLanguage
                )
                
                await MainActor.run {
                    self.isProcessing = false
                    
                    if let audioData = result.audioData {
                        self.playAudio(audioData)
                    }
                    
                    // Audio playback (tracking removed)
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func playAudio(_ audioData: Data) {
        isPlaying = true
        
        audioManager.playAudio(audioData) { success in
            Task { @MainActor in
                self.isPlaying = false
                if !success {
                    self.showError("Failed to play audio")
                }
            }
        }
    }
    
    private func retryLastTranslation() {
        if !transcribedText.isEmpty {
            translateText()
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func clearConversationText() {
        transcribedText = ""
        translatedText = ""
        showError = false
        errorMessage = ""
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Setup
    
    private func setupAudio() {
        audioManager.setupSession()
    }
    
    private func loadLanguages() {
        // Languages are loaded from the service
    }
    
    private func requestPermissions() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied:
                    print("❌ Speech recognition denied")
                case .restricted:
                    print("❌ Speech recognition restricted")
                case .notDetermined:
                    print("⚠️ Speech recognition not determined")
                @unknown default:
                    print("❌ Speech recognition unknown status")
                }
            }
        }
    }
    
    // MARK: - Anonymous/Authenticated Mode Management
    
    private func updateModeBasedOnAuth() {
        isAnonymousMode = !auth.isSignedIn
    }
    
    private func migrateFromAnonymousMode() {
        let creditsToMigrate = anonymousCredits.migrateToAccount()
        if creditsToMigrate > 0 {
            credits.add(seconds: creditsToMigrate)
            anonymousCredits.clearAfterMigration()
            print("✅ Migrated \(creditsToMigrate) seconds from anonymous to authenticated account")
        }
        isAnonymousMode = false
        Task {
            await credits.grantStarterIfNeededWithDeviceThrottle()
        }
    }
}

// MARK: - Helper Views

fileprivate struct LanguagePickerView: View {
    fileprivate let pickerType: LanguagePickerType
    @Binding var sourceLanguage: String
    @Binding var targetLanguage: String
    @Environment(\.dismiss) private var dismiss
    
    private var selectedLanguage: Binding<String> {
        pickerType == .source ? $sourceLanguage : $targetLanguage
    }
    
    var body: some View {
        List(Language.defaultLanguages, id: \.code) { language in
            LanguagePickerRow(
                language: language,
                isSelected: language.code == selectedLanguage.wrappedValue,
                onSelect: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedLanguage.wrappedValue = language.code
                    }
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    
                    dismiss()
                }
            )
        }
        .navigationTitle(pickerType == .source ? "Source Language" : "Target Language")
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



// MARK: - View Modifiers

extension View {
    func purchaseSheet(isPresented: Binding<Bool>, isAnonymousMode: Bool) -> some View {
        self.sheet(isPresented: isPresented) {
            if isAnonymousMode {
                AnonymousPurchaseSheet()
            } else {
                PurchaseSheet()
            }
        }
    }
    
    func profileSheet(isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            NavigationView {
                ProfileView()
            }
        }
    }
    
    func usageStatsSheet(isPresented: Binding<Bool>) -> some View {
        self.sheet(isPresented: isPresented) {
            NavigationView {
                UsageStatisticsView()
            }
        }
    }
    
    fileprivate func languagePickerSheet(item: Binding<LanguagePickerType?>, sourceLanguage: Binding<String>, targetLanguage: Binding<String>) -> some View {
        self.sheet(item: item) { pickerType in
            NavigationView {
                LanguagePickerView(
                    pickerType: pickerType,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            }
        }
    }
    
    func errorAlert(isPresented: Binding<Bool>, message: String, onRetry: @escaping () -> Void) -> some View {
        self.alert("Translation Error", isPresented: isPresented) {
            if !message.contains("✅") {
                Button(NSLocalizedString("retry", comment: "Retry button text")) {
                    onRetry()
                }
            }
        } message: {
            Text(message)
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
