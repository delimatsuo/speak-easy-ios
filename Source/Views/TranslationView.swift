import SwiftUI

struct TranslationView: View {
    @EnvironmentObject var viewModel: TranslationViewModel
    @Environment(\.dynamicTypeSize) var dynamicType
    @State private var showingLanguageSelector = false
    @State private var languageSelectorTarget: Language? = nil
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastNotification.ToastType = .info
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 16) {
                    languageSelectionArea
                    
                    transcriptionDisplay
                    
                    translationDisplay
                    
                    Spacer()
                    
                    recordButtonArea
                }
                .padding(.horizontal, 16)
                .navigationTitle("Universal Translator")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("History") {
                            // TODO: Navigate to history
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Settings") {
                            // TODO: Navigate to settings
                        }
                    }
                }
                .sheet(isPresented: $showingLanguageSelector) {
                    LanguageSelectorView(
                        selectedLanguage: languageSelectorTarget ?? viewModel.sourceLanguage,
                        onLanguageSelected: { language in
                            if languageSelectorTarget == viewModel.sourceLanguage {
                                viewModel.sourceLanguage = language
                            } else {
                                viewModel.targetLanguage = language
                            }
                            showingLanguageSelector = false
                        }
                    )
                }
                
                // Error overlay
                if let error = viewModel.currentError {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.currentError = nil
                        }
                    
                    ErrorOverlay(
                        error: error,
                        onRetry: {
                            viewModel.currentError = nil
                            if case .speechRecognitionFailed = error {
                                viewModel.startRecording()
                            } else if !viewModel.transcribedText.isEmpty {
                                Task {
                                    await viewModel.translateText(viewModel.transcribedText)
                                }
                            }
                        },
                        onDismiss: {
                            viewModel.currentError = nil
                        }
                    )
                }
                
                // Toast notification
                VStack {
                    ToastNotification(
                        message: toastMessage,
                        type: toastType,
                        isShowing: $showingToast
                    )
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
        }
        .background(Color(.systemBackground))
        .accessibilityAction(.default) {
            if case .idle = viewModel.recordingState {
                viewModel.startRecording()
            } else if case .recording = viewModel.recordingState {
                viewModel.stopRecording()
            }
        }
        .accessibilityAction(named: "Swap languages") {
            viewModel.swapLanguages()
        }
    }
    
    private var languageSelectionArea: some View {
        HStack(spacing: 8) {
            LanguageButton(
                language: viewModel.sourceLanguage,
                label: "Source"
            ) {
                languageSelectorTarget = viewModel.sourceLanguage
                showingLanguageSelector = true
            }
            
            SwapButton {
                viewModel.swapLanguages()
            }
            
            LanguageButton(
                language: viewModel.targetLanguage,
                label: "Target"
            ) {
                languageSelectorTarget = viewModel.targetLanguage
                showingLanguageSelector = true
            }
        }
        .frame(height: 120)
    }
    
    private var transcriptionDisplay: some View {
        TextDisplayCard(
            text: viewModel.transcribedText,
            language: viewModel.sourceLanguage,
            placeholder: "Tap the record button to start speaking...",
            isTranslation: false,
            onCopy: {
                showToast(message: "Text copied to clipboard", type: .success)
            }
        )
        .frame(minHeight: 80)
    }
    
    private var translationDisplay: some View {
        TextDisplayCard(
            text: viewModel.translatedText,
            language: viewModel.targetLanguage,
            placeholder: "Translation will appear here...",
            isTranslation: true,
            onCopy: {
                showToast(message: "Translation copied to clipboard", type: .success)
            }
        )
        .frame(minHeight: 80)
    }
    
    private func showToast(message: String, type: ToastNotification.ToastType) {
        toastMessage = message
        toastType = type
        withAnimation {
            showingToast = true
        }
    }
    
    private var recordButtonArea: some View {
        VStack(spacing: 20) {
            // Real-time progress indicator
            TranslationProgressView(
                state: viewModel.recordingState,
                progress: progressValue
            )
            .frame(height: progressIndicatorHeight)
            
            // Waveform for recording state
            if case .recording = viewModel.recordingState {
                WaveformView(audioLevel: viewModel.audioLevel)
                    .frame(height: 60)
                    .transition(.scale.combined(with: .opacity))
            }
            
            HStack(spacing: 44) {
                SecondaryButton(
                    icon: "keyboard",
                    isActive: viewModel.isTextInputMode
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isTextInputMode.toggle()
                    }
                }
                
                RecordButton(
                    state: viewModel.recordingState,
                    onTapGesture: {
                        if case .recording = viewModel.recordingState {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    }
                )
                
                SecondaryButton(
                    icon: "play.fill",
                    isActive: case .playback = viewModel.recordingState
                ) {
                    Task {
                        await viewModel.playTranslation()
                    }
                }
            }
        }
        .frame(height: totalRecordAreaHeight)
        .padding(.bottom, 34) // Safe area bottom
        .animation(.easeInOut(duration: 0.3), value: viewModel.recordingState)
    }
    
    // MARK: - Computed Properties for Real-time Updates
    
    private var progressValue: Double {
        switch viewModel.recordingState {
        case .recording:
            return min(viewModel.audioLevel, 1.0)
        case .processing:
            return 0.6 // Indeterminate progress
        case .playback:
            return 0.8 // Audio playback progress
        default:
            return 0.0
        }
    }
    
    private var progressIndicatorHeight: CGFloat {
        switch viewModel.recordingState {
        case .idle, .error:
            return 0
        default:
            return 40
        }
    }
    
    private var totalRecordAreaHeight: CGFloat {
        var height: CGFloat = 120 // Base height for buttons
        
        if case .recording = viewModel.recordingState {
            height += 60 // Waveform height
        }
        
        if progressIndicatorHeight > 0 {
            height += progressIndicatorHeight + 20 // Progress view + spacing
        }
        
        return height
    }
}

#Preview {
    NavigationView {
        TranslationView()
            .environmentObject(TranslationViewModel())
    }
}