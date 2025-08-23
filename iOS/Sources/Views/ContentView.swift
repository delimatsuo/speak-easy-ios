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
import WatchConnectivity

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
    @StateObject private var watchSession = WatchSessionManager.shared
    
    // Anonymous mode state
    @State private var isAnonymousMode = true
    
    @State private var sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "en"
    @State private var targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "es"
    @State private var transcribedText = ""
    @State private var translatedText = ""
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
    
    // Cache audio data to avoid re-processing on replay
    @State private var cachedTranslationAudio: Data?
    
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
            .errorAlert(isPresented: $showError, message: errorMessage, onRetry: retryLastTranslation, onCancel: {
                // Reset state when user cancels
                isProcessing = false
                // Don't clear the text, just the processing state
            })
            .onAppear(perform: setupView)
            .onDisappear(perform: cleanup)
            .onChange(of: sourceLanguage) { newValue in
                UserDefaults.standard.set(newValue, forKey: "sourceLanguage")
                watchSession.syncLanguages(source: newValue, target: targetLanguage)
            }
            .onChange(of: targetLanguage) { newValue in
                UserDefaults.standard.set(newValue, forKey: "targetLanguage")
                watchSession.syncLanguages(source: sourceLanguage, target: newValue)
            }
            .onChange(of: auth.isSignedIn, perform: handleAuthChange)
            .onChange(of: credits.remainingSeconds) { _ in
                // Sync credit balance to Watch
                watchSession.updateCredits()
            }
            .onChange(of: anonymousCredits.remainingSeconds) { _ in
                // Sync anonymous credit balance to Watch if in anonymous mode
                if isAnonymousMode {
                    watchSession.updateCredits()
                }
            }
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
                VStack(spacing: UIDevice.current.userInterfaceIdiom == .pad ? 16 : DesignConstants.Layout.contentSpacing) {
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
        VStack(spacing: 8) {
            HeroHeader(
                title: NSLocalizedString("app_name", comment: "App name displayed in header"),
                subtitle: NSLocalizedString("app_subtitle", comment: "App subtitle describing main functionality"),
                onHistory: nil,
                onProfile: { showProfile = true },
                style: .fullBleed,
                remainingSeconds: isAnonymousMode ? anonymousCredits.remainingSeconds : credits.remainingSeconds
            )
            
            // Watch Connection Status
            if watchSession.isPaired {
                HStack {
                    Image(systemName: watchSession.isReachable ? "applewatch" : "applewatch.slash")
                        .font(.caption)
                        .foregroundColor(watchSession.isReachable ? .green : .orange)
                    Text(watchSession.isReachable ? "Watch Connected" : "Watch Disconnected")
                        .font(.caption)
                        .foregroundColor(watchSession.isReachable ? .green : .orange)
                    Spacer()
                }
                .padding(.horizontal)
            }
        }
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
            isRecording: .constant(audioManager.isRecording), // Use AudioManager's state directly
            isProcessing: isProcessing,
            isPlaying: isPlaying,
            action: toggleRecording
        )
        .padding(.vertical, 20)
        .disabled(!audioManager.isRecording && !isProcessing && !isPlaying && currentCredits == 0)
    }
    
    @ViewBuilder
    private var conversationSection: some View {
        if !transcribedText.isEmpty || !translatedText.isEmpty {
            ConversationBubblesView(
                sourceText: transcribedText,
                targetText: translatedText,
                onPlay: playTranslation,
                onShare: shareTranslation
            )
        } else if audioManager.isRecording {
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
        // Sync swapped languages to Watch
        watchSession.syncLanguages(source: sourceLanguage, target: targetLanguage)
    }
    
    private func setupView() {
        setupAudio()
        loadLanguages()
        requestPermissions()
        
        // Activate Watch connectivity
        watchSession.activate()
        
        // Sync initial languages to Watch
        watchSession.syncLanguages(source: sourceLanguage, target: targetLanguage)
        
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
            audioManager.forceCleanupAllSessions()
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
        // Clean up timer
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Clean up observers
        if let observer = observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ShowPurchaseSheet"), object: nil)
        
        // End any active background task
        endBackgroundTask()
    }
    
    private func handleAuthChange(_ isSignedIn: Bool) {
        // Clean up any active audio sessions to prevent crashes
        audioManager.forceCleanupAllSessions()
        
        if isSignedIn && isAnonymousMode {
            // User just signed in - migrate from anonymous to authenticated
            migrateFromAnonymousMode()
        } else if !isSignedIn && !isAnonymousMode {
            // User signed out - migrate credits back to device and switch to anonymous mode
            migrateToAnonymousMode()
        }
        
        // CRITICAL FIX: Always update anonymous mode state to match auth state
        updateModeBasedOnAuth()
        
        // Clear any UI state that might be stale
        clearConversationText()
        
        // Re-setup audio session after auth change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.audioManager.setupSession()
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        print("🔍 [UI] toggleRecording called - Current state: audioManager.isRecording=\(audioManager.isRecording)")
        
        if audioManager.isRecording {
            print("🔍 [UI] Stopping recording...")
            stopRecording()
        } else {
            guard canStartTranslation else {
                print("🔍 [UI] Cannot start translation - showing purchase sheet")
                showPurchaseSheet = true
                return
            }
            print("🔍 [UI] Starting recording...")
            startRecording()
        }
        
        // Track usage (removed recordInteraction as it doesn't exist in UsageTrackingService)
    }
    
    private func startRecording() {
        print("🔍 [UI] startRecording called")
        clearConversationText()
        
        // Start background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            self.endBackgroundTask()
        }
        
        recordingDuration = 0
        print("🔍 [UI] UI state updated: recordingDuration=0")
        
        // Start the recording timer to deduct credits per second
        startRecordingTimer()
        
        print("🔍 [UI] Calling audioManager.startRecording...")
        audioManager.startRecording { success in
            Task { @MainActor in
                print("🔍 [UI] audioManager.startRecording completion: success=\(success)")
                if success {
                    // Defer live transcription to avoid blocking UI
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        do {
                            print("🔍 [UI] Starting live transcription for language: \(sourceLanguage)")
                            try audioManager.startLiveTranscription(language: sourceLanguage)
                        } catch {
                            print("❌ [UI] Failed to start live transcription: \(error)")
                            // Don't show error for transcription failure - recording still works
                        }
                    }
                } else {
                    print("❌ [UI] Recording failed - resetting state")
                    showError("Failed to start recording")
                    recordingTimer?.invalidate()
                    recordingTimer = nil
                }
            }
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                // Deduct credits per elapsed second from appropriate manager
                if isAnonymousMode {
                    anonymousCredits.deduct(seconds: 1)
                } else {
                    credits.deduct(seconds: 1)
                }
                recordingDuration += 1
                
                // Stop if out of credits
                if currentCredits <= 0 {
                    stopRecording()
                    showPurchaseSheet = true
                    return
                }
                
                // Safety cap at 2 minutes
                if recordingDuration >= 120 {
                    stopRecording()
                    showError("Recording stopped at 2-minute limit")
                    return
                }
            }
        }
    }
    
    private func stopRecording() {
        print("🔍 [UI] stopRecording called")
        recordingTimer?.invalidate()
        recordingTimer = nil
        print("🔍 [UI] UI state updated: timer invalidated")
        
        // Stop live transcription first
        print("🔍 [UI] Stopping live transcription...")
        audioManager.stopLiveTranscription()
        
        // Copy the transcribed text from AudioManager
        transcribedText = audioManager.transcribedText
        print("🔍 [UI] Transcribed text: '\(transcribedText.prefix(50))...' (length: \(transcribedText.count))")
        
        print("🔍 [UI] Stopping audio recording...")
        audioManager.stopRecording { _ in
            // Completion handler
        }
        
        if !transcribedText.isEmpty {
            print("🔍 [UI] Text detected - starting translation")
            translateText()
        } else {
            print("❌ [UI] No speech detected")
            showError("No speech detected. Please try again.")
        }
        
        endBackgroundTask()
        print("🔍 [UI] stopRecording completed")
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
                    translatedText = result.translatedText
                    isProcessing = false
                    
                    // Cache audio data for replay
                    cachedTranslationAudio = result.audioData
                    
                    // Auto-play the translation
                    if let audioData = result.audioData {
                        playAudio(audioData)
                    }
                }
            } catch {
                let translationDuration = Date().timeIntervalSince(translationStartTime)
                print("❌ Translation failed after \(String(format: "%.2f", translationDuration))s: \(error)")
                
                await MainActor.run {
                    isProcessing = false
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func playTranslation() {
        guard !translatedText.isEmpty else { return }
        
        // Use cached audio if available, otherwise re-generate
        if let cachedAudio = cachedTranslationAudio {
            print("🔄 Playing cached translation audio")
            playAudio(cachedAudio)
        } else {
            print("⚠️ No cached audio found, re-generating translation audio")
            isProcessing = true
            
            Task {
                do {
                    let result = try await translationService.translateWithAudio(
                        text: translatedText,
                        from: targetLanguage,
                        to: targetLanguage
                    )
                    
                    await MainActor.run {
                        isProcessing = false
                        
                        // Cache the audio for future replays
                        cachedTranslationAudio = result.audioData
                        
                        if let audioData = result.audioData {
                            playAudio(audioData)
                        }
                    }
                } catch {
                    await MainActor.run {
                        isProcessing = false
                        showError(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func playAudio(_ audioData: Data) {
        isPlaying = true
        
        audioManager.playAudio(audioData) { success in
            Task { @MainActor in
                isPlaying = false
                if !success {
                    showError("Failed to play audio")
                }
            }
        }
    }
    
    private func shareTranslation() {
        guard !translatedText.isEmpty else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [translatedText],
            applicationActivities: nil
        )
        
        // For iPad: Set up popover presentation
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = window
                activityViewController.popoverPresentationController?.sourceRect = CGRect(
                    x: window.bounds.midX,
                    y: window.bounds.midY,
                    width: 0,
                    height: 0
                )
                activityViewController.popoverPresentationController?.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
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
        cachedTranslationAudio = nil  // Clear cached audio
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
        let newAnonymousMode = !auth.isSignedIn
        print("🔍 updateModeBasedOnAuth: auth.isSignedIn=\(auth.isSignedIn), old isAnonymousMode=\(isAnonymousMode), new isAnonymousMode=\(newAnonymousMode)")
        isAnonymousMode = newAnonymousMode
        print("🔍 After update: isAnonymousMode=\(isAnonymousMode), will show \(isAnonymousMode ? "AnonymousPurchaseSheet" : "PurchaseSheet")")
    }
    
    private func migrateFromAnonymousMode() {
        // Clean separation: Just switch to cloud account, no credit transfer
        isAnonymousMode = false
        print("✅ Switched to cloud account")
        
        Task {
            await credits.grantStarterIfNeededWithDeviceThrottle()
        }
    }
    
    private func migrateToAnonymousMode() {
        // Clean separation: Just switch to device account, no credit transfer
        isAnonymousMode = true
        print("✅ Switched to device account")
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
    
    func errorAlert(isPresented: Binding<Bool>, message: String, onRetry: @escaping () -> Void, onCancel: @escaping () -> Void = {}) -> some View {
        self.alert("Translation Error", isPresented: isPresented) {
            // Always show Cancel button to let users go back
            Button(NSLocalizedString("cancel", comment: "Cancel button text"), role: .cancel) {
                onCancel()
            }
            
            // Show Retry button if it makes sense
            if !message.contains("✅") && !message.contains("No speech detected") {
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
