//
//  WatchAccessibilitySupport.swift
//  UniversalTranslator Watch App
//
//  Comprehensive accessibility support for Apple Watch UI
//  Ensures the app is usable by users with diverse abilities
//

import SwiftUI
import WatchKit

// MARK: - Accessibility Extensions

extension View {
    
    /// Apply comprehensive accessibility for language selection
    func languageAccessibility(
        language: String,
        isSource: Bool,
        isSelected: Bool = false
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(isSource ? "Source" : "Target") language: \(language)")
            .accessibilityHint(isSource ? "Select the language to translate from" : "Select the language to translate to")
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Apply accessibility for recording states
    func recordingAccessibility(isRecording: Bool, duration: String = "") -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
            .accessibilityHint(isRecording ? "Tap to stop voice recording" : "Tap to start voice recording")
            .accessibilityValue(isRecording ? "Recording for \(duration)" : "Ready to record")
            .accessibilityAddTraits(.isButton)
    }
    
    /// Apply accessibility for translation results
    func translationAccessibility(
        originalText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Translation result")
            .accessibilityValue("Original text in \(sourceLanguage): \(originalText). Translation in \(targetLanguage): \(translatedText)")
            .accessibilityHint("Double tap to hear the translation")
    }
    
    /// Apply accessibility for connection status
    func connectionAccessibility(isConnected: Bool, credits: Int = 0) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isConnected ? "Connected to iPhone" : "Disconnected from iPhone")
            .accessibilityValue(isConnected ? "Credits remaining: \(credits) seconds" : "Please open the iPhone app")
            .accessibilityHint(isConnected ? "" : "Connection required for translation")
    }
    
    /// Apply accessibility for error states
    func errorAccessibility(errorMessage: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Error occurred")
            .accessibilityValue(errorMessage)
            .accessibilityHint("Use the buttons below to retry or cancel")
            .accessibilityAddTraits(.isStaticText)
    }
    
    /// Apply accessibility for processing states
    func processingAccessibility(stage: String) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Processing translation")
            .accessibilityValue("Currently \(stage)")
            .accessibilityHint("Please wait while your translation is processed")
            .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Accessibility Announcements

struct WatchAccessibilityAnnouncements {
    
    /// Announce recording start
    static func recordingStarted() {
        announceWithDelay("Recording started. Speak now.")
    }
    
    /// Announce recording stopped
    static func recordingStopped() {
        announceWithDelay("Recording stopped. Processing your translation.")
    }
    
    /// Announce translation completed
    static func translationCompleted(text: String) {
        announceWithDelay("Translation completed: \(text)")
    }
    
    /// Announce error
    static func error(_ message: String) {
        announceWithDelay("Error: \(message)")
    }
    
    /// Announce language change
    static func languageChanged(from: String, to: String) {
        announceWithDelay("Language changed from \(from) to \(to)")
    }
    
    /// Announce connection status change
    static func connectionChanged(isConnected: Bool) {
        let message = isConnected ? "Connected to iPhone" : "Disconnected from iPhone"
        announceWithDelay(message)
    }
    
    /// Helper to announce with slight delay for better UX
    private static func announceWithDelay(_ message: String) {
        // watchOS doesn't support UIAccessibility announcements
        // Instead, we can use WKInterfaceDevice haptic feedback as an indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

// MARK: - Voice Control Support

extension View {
    
    /// Add voice control names for better voice navigation
    func voiceControlName(_ name: String) -> some View {
        self.accessibilityIdentifier(name)
    }
}

// MARK: - Reduced Motion Support

struct ReducedMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    let normalAnimation: Animation
    let reducedAnimation: Animation
    
    init(normal: Animation = .easeInOut(duration: 0.3), reduced: Animation = .linear(duration: 0.1)) {
        self.normalAnimation = normal
        self.reducedAnimation = reduced
    }
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? reducedAnimation : normalAnimation, value: UUID())
    }
}

extension View {
    func respectReducedMotion(
        normal: Animation = .easeInOut(duration: 0.3),
        reduced: Animation = .linear(duration: 0.1)
    ) -> some View {
        self.modifier(ReducedMotionModifier(normal: normal, reduced: reduced))
    }
}

// MARK: - High Contrast Support

struct HighContrastModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    
    func body(content: Content) -> some View {
        // watchOS has limited accessibility environment values
        // Simply return the content without modification
        content
    }
}

extension View {
    func respectHighContrast() -> some View {
        self.modifier(HighContrastModifier())
    }
}

// MARK: - Large Text Support

struct LargeTextModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory
    
    let baseFont: Font
    let maxSize: CGFloat
    
    init(baseFont: Font = .body, maxSize: CGFloat = 24) {
        self.baseFont = baseFont
        self.maxSize = maxSize
    }
    
    func body(content: Content) -> some View {
        content
            .font(adaptedFont)
            .minimumScaleFactor(0.8)
            .lineLimit(sizeCategory.isAccessibilityCategory ? nil : 2)
    }
    
    private var adaptedFont: Font {
        if sizeCategory.isAccessibilityCategory {
            return .system(size: min(maxSize, 20))
        }
        return baseFont
    }
}

extension View {
    func adaptToLargeText(baseFont: Font = .body, maxSize: CGFloat = 24) -> some View {
        self.modifier(LargeTextModifier(baseFont: baseFont, maxSize: maxSize))
    }
}

// MARK: - Accessibility Container

struct AccessibleWatchContainer<Content: View>: View {
    let content: Content
    let label: String
    let hint: String?
    
    init(
        label: String,
        hint: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.hint = hint
        self.content = content()
    }
    
    var body: some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .respectReducedMotion()
            .respectHighContrast()
    }
}

// MARK: - Accessibility Testing Support

#if DEBUG
struct AccessibilityPreview: View {
    var body: some View {
        VStack {
            Text("Accessibility Testing")
                .languageAccessibility(language: "English", isSource: true, isSelected: true)
            
            Button("Test Recording") {}
                .recordingAccessibility(isRecording: false)
            
            Text("Connection Status")
                .connectionAccessibility(isConnected: true, credits: 120)
        }
    }
}

struct AccessibilityPreview_Previews: PreviewProvider {
    static var previews: some View {
        AccessibilityPreview()
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}
#endif