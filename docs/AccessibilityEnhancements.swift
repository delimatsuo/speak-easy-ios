//
//  AccessibilityEnhancements.swift
//  Mervyn Talks - Comprehensive Accessibility System
//
//  Enhanced accessibility features following WCAG 2.1 AA guidelines
//  and iOS accessibility best practices
//

import SwiftUI
import AccessibilityCore

// MARK: - Accessibility Configuration
struct AccessibilityConfig {
    static let minimumTapTarget: CGFloat = 44
    static let minimumContrastRatio = 4.5 // WCAG AA standard
    static let preferredAnimationDuration: TimeInterval = 0.3
    static let reducedAnimationDuration: TimeInterval = 0.1
    
    // Dynamic Type size limits
    static let minDynamicTypeSize = DynamicTypeSize.small
    static let maxDynamicTypeSize = DynamicTypeSize.accessibility5
}

// MARK: - Enhanced Accessibility Modifiers
extension View {
    
    /// Enhanced accessibility with comprehensive VoiceOver support
    func enhancedAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = [],
        sortPriority: Double? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
            .accessibilityRemoveTraits(.isImage) // Ensure buttons aren't read as images
            .accessibilitySortPriority(sortPriority ?? 0)
    }
    
    /// Ensure minimum tap target size for accessibility
    func accessibleTapTarget(minSize: CGFloat = AccessibilityConfig.minimumTapTarget) -> some View {
        self
            .frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
    }
    
    /// Enhanced button accessibility with haptic feedback
    func accessibleButton(
        label: String,
        hint: String? = nil,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) -> some View {
        self
            .enhancedAccessibility(
                label: label,
                hint: hint,
                traits: [.isButton]
            )
            .accessibleTapTarget()
            .onTapGesture {
                // Provide haptic feedback for accessibility
                let impactFeedback = UIImpactFeedbackGenerator(style: hapticStyle)
                impactFeedback.impactOccurred()
            }
    }
    
    /// Support for reduced motion preferences
    func respectsReducedMotion<T: Equatable>(
        animation: Animation = .easeInOut(duration: AccessibilityConfig.preferredAnimationDuration),
        value: T
    ) -> some View {
        self.modifier(ReducedMotionModifier(animation: animation, value: value))
    }
    
    /// Enhanced text readability with proper contrast
    func readableText() -> some View {
        self
            .dynamicTypeSize(AccessibilityConfig.minDynamicTypeSize...AccessibilityConfig.maxDynamicTypeSize)
            .lineLimit(nil) // Allow text to expand
            .multilineTextAlignment(.leading)
    }
    
    /// Focus management for VoiceOver navigation
    func accessibilityFocusable(
        _ isFocused: Binding<Bool>,
        priority: AccessibilityFocusPriority = .default
    ) -> some View {
        self
            .accessibilityFocused(isFocused)
            .accessibilityAction(.default) {
                isFocused.wrappedValue = true
            }
    }
}

// MARK: - Reduced Motion Modifier
struct ReducedMotionModifier<T: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let animation: Animation
    let value: T
    
    func body(content: Content) -> some View {
        content
            .animation(
                reduceMotion ? .none : animation,
                value: value
            )
    }
}

// MARK: - Accessible Color System with High Contrast
extension Color {
    
    /// High contrast colors for accessibility
    static func accessibleColor(
        normal: Color,
        highContrast: Color,
        environment: ColorScheme = .light
    ) -> Color {
        // In production, this would check for high contrast mode
        // For now, returning the normal color with accessibility considerations
        return normal
    }
    
    /// Ensure proper contrast ratios
    static var accessiblePrimary: Color {
        Color("AccessiblePrimary", bundle: .main) // Would be defined in asset catalog
    }
    
    static var accessibleSecondary: Color {
        Color("AccessibleSecondary", bundle: .main)
    }
    
    /// Text colors with guaranteed contrast ratios
    static var accessibleTextOnLight: Color {
        Color(red: 0.1, green: 0.1, blue: 0.1) // Near black for maximum contrast
    }
    
    static var accessibleTextOnDark: Color {
        Color(red: 0.95, green: 0.95, blue: 0.95) // Near white for maximum contrast
    }
}

// MARK: - Accessible Button Components
struct AccessiblePrimaryButton: View {
    let title: String
    let action: () -> Void
    let isEnabled: Bool
    let isLoading: Bool
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @FocusState private var isFocused: Bool
    
    init(
        _ title: String,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.action = action
        self.isEnabled = isEnabled
        self.isLoading = isLoading
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .accessibilityHidden(true)
                }
                
                Text(title)
                    .font(.appBodyEmphasized)
                    .readableText()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.button)
                    .fill(buttonBackgroundColor)
            )
            .foregroundColor(buttonTextColor)
        }
        .disabled(!isEnabled || isLoading)
        .accessibleTapTarget(minSize: 48) // Slightly larger for better accessibility
        .enhancedAccessibility(
            label: accessibilityLabel,
            hint: accessibilityHint,
            traits: isEnabled ? [.isButton] : [.isButton, .notEnabled]
        )
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .respectsReducedMotion(value: isFocused)
    }
    
    private var buttonBackgroundColor: Color {
        if !isEnabled || isLoading {
            return .appSecondaryText.opacity(0.3)
        }
        return .appPrimary
    }
    
    private var buttonTextColor: Color {
        return .white
    }
    
    private var accessibilityLabel: String {
        return title
    }
    
    private var accessibilityHint: String {
        if isLoading {
            return "Loading, please wait"
        } else if !isEnabled {
            return "Button is disabled"
        } else {
            return "Double tap to activate"
        }
    }
}

// MARK: - Accessible Language Picker
struct AccessibleLanguagePicker: View {
    @Binding var selectedLanguage: String
    let languages: [Language]
    let title: String
    let icon: String
    
    @State private var isExpanded = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            Label(title, systemImage: icon)
                .font(.appCaption)
                .foregroundColor(.appSecondaryText)
                .readableText()
            
            Menu {
                ForEach(languages) { language in
                    Button(action: {
                        selectedLanguage = language.code
                        announceLanguageChange(language.name)
                    }) {
                        HStack {
                            Text(language.flag)
                            Text(language.name)
                            if selectedLanguage == language.code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .enhancedAccessibility(
                        label: "\(language.name)",
                        hint: selectedLanguage == language.code ? "Currently selected" : "Select this language",
                        traits: [.isButton]
                    )
                }
            } label: {
                HStack {
                    if let selectedLang = languages.first(where: { $0.code == selectedLanguage }) {
                        Text(selectedLang.flag)
                        Text(selectedLang.name)
                            .font(.appBody)
                            .readableText()
                    } else {
                        Text("Select Language")
                            .font(.appBody)
                            .readableText()
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                }
                .padding(.horizontal, AppSpacing.small)
                .padding(.vertical, AppSpacing.xSmall + 2)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.small)
                        .fill(Color.appTertiaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.small)
                                .stroke(isFocused ? Color.appPrimary : Color.clear, lineWidth: 2)
                        )
                )
            }
            .accessibleTapTarget()
            .enhancedAccessibility(
                label: "Language picker for \(title.lowercased())",
                hint: "Double tap to open language selection menu. Currently selected: \(currentLanguageName)",
                traits: [.isButton, .updatesFrequently]
            )
            .focused($isFocused)
            .respectsReducedMotion(value: isFocused)
        }
    }
    
    private var currentLanguageName: String {
        languages.first(where: { $0.code == selectedLanguage })?.name ?? "Unknown"
    }
    
    private func announceLanguageChange(_ languageName: String) {
        // Announce the language change to VoiceOver users
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(notification: .announcement, argument: "Language changed to \(languageName)")
        }
    }
}

// MARK: - Accessible Text Display Card
struct AccessibleTextCard: View {
    let text: String
    let title: String
    let icon: String
    let language: String
    let isOriginal: Bool
    let onReplay: (() -> Void)?
    let onCopy: (() -> Void)?
    
    @State private var showCopyConfirmation = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            // Header with title and actions
            HStack {
                Label(title, systemImage: icon)
                    .font(.appCaption)
                    .foregroundColor(.appSecondaryText)
                    .readableText()
                
                Spacer()
                
                // Action buttons
                HStack(spacing: AppSpacing.xSmall) {
                    if let onCopy = onCopy, !text.isEmpty {
                        Button(action: {
                            onCopy()
                            showCopyConfirmation = true
                            announceCopy()
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.appPrimary)
                        }
                        .accessibleButton(
                            label: "Copy text",
                            hint: "Double tap to copy this text to clipboard"
                        )
                    }
                    
                    if let onReplay = onReplay, !isOriginal {
                        Button(action: {
                            onReplay()
                            announceReplay()
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.caption)
                                .foregroundColor(.appPrimary)
                        }
                        .accessibleButton(
                            label: "Replay audio",
                            hint: "Double tap to replay the translation audio"
                        )
                    }
                }
            }
            
            // Text content
            ScrollView {
                Text(text.isEmpty ? placeholderText : text)
                    .font(isOriginal ? .appBody : .appBodyEmphasized)
                    .foregroundColor(text.isEmpty ? .appTertiaryText : .appPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .readableText()
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, AppSpacing.xxSmall)
            }
            .frame(minHeight: 60)
        }
        .padding(AppSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.card)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.card)
                        .stroke(cardBorderColor, lineWidth: cardBorderWidth)
                )
        )
        .enhancedAccessibility(
            label: accessibilityLabel,
            hint: accessibilityHint,
            value: text.isEmpty ? "Empty" : text,
            traits: [.updatesFrequently, .allowsDirectInteraction]
        )
        .accessibilityAction(named: "Copy text") {
            onCopy?()
        }
        .accessibilityAction(named: "Replay audio") {
            onReplay?()
        }
        .focused($isFocused)
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .respectsReducedMotion(value: isFocused)
        .alert("Text Copied", isPresented: $showCopyConfirmation) {
            Button("OK") { }
        } message: {
            Text("The text has been copied to your clipboard.")
        }
    }
    
    private var placeholderText: String {
        isOriginal ? "Spoken text will appear here..." : "Translation will appear here..."
    }
    
    private var cardBackgroundColor: Color {
        isOriginal ? Color.appSecondaryBackground : Color.appPrimary.opacity(0.05)
    }
    
    private var cardBorderColor: Color {
        if isFocused {
            return .appPrimary
        }
        return isOriginal ? Color.clear : Color.appPrimary.opacity(0.2)
    }
    
    private var cardBorderWidth: CGFloat {
        isFocused ? 2 : (isOriginal ? 0 : 1)
    }
    
    private var accessibilityLabel: String {
        let typeLabel = isOriginal ? "Original text" : "Translation"
        return "\(typeLabel) in \(language)"
    }
    
    private var accessibilityHint: String {
        if text.isEmpty {
            return isOriginal ? "Original spoken text will appear here when you record" : "Translation will appear here after processing"
        } else {
            var hint = "Double tap to interact with text"
            if onCopy != nil {
                hint += ", swipe up for copy option"
            }
            if onReplay != nil {
                hint += ", swipe up for replay option"
            }
            return hint
        }
    }
    
    private func announceCopy() {
        UIAccessibility.post(notification: .announcement, argument: "Text copied to clipboard")
    }
    
    private func announceReplay() {
        UIAccessibility.post(notification: .announcement, argument: "Replaying audio")
    }
}

// MARK: - Accessible Recording Button
struct AccessibleRecordButton: View {
    let isRecording: Bool
    let isProcessing: Bool
    let isPlaying: Bool
    let action: () -> Void
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isPulsing = false
    @State private var scale: CGFloat = 1.0
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: {
            action()
            provideHapticFeedback()
            announceStateChange()
        }) {
            ZStack {
                // Pulse animation background (only if motion is not reduced)
                if isRecording && !reduceMotion {
                    Circle()
                        .fill(Color.appRecording.opacity(0.3))
                        .frame(width: 220, height: 220)
                        .scaleEffect(isPulsing ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                }
                
                // Main button
                Circle()
                    .fill(buttonGradient)
                    .frame(width: buttonSize, height: buttonSize)
                    .overlay(
                        Circle()
                            .stroke(isFocused ? Color.white : Color.clear, lineWidth: 4)
                    )
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                
                // Icon or loading indicator
                Group {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: buttonIcon)
                            .font(.system(size: iconSize, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .accessibleTapTarget(minSize: max(buttonSize + 20, 64)) // Larger tap target
        .disabled(isProcessing)
        .scaleEffect(scale)
        .enhancedAccessibility(
            label: accessibilityLabel,
            hint: accessibilityHint,
            traits: isProcessing ? [.isButton, .notEnabled] : [.isButton],
            sortPriority: 100 // High priority for main action
        )
        .focused($isFocused)
        .onChange(of: isFocused) { focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                scale = focused ? 1.1 : 1.0
            }
        }
        .onChange(of: isRecording) { recording in
            if recording && !reduceMotion {
                isPulsing = true
            } else {
                isPulsing = false
            }
        }
        .onAppear {
            if isRecording && !reduceMotion {
                isPulsing = true
            }
        }
    }
    
    private var buttonSize: CGFloat {
        switch DeviceSize.current {
        case .compact:
            return isRecording ? 150 : 140
        case .regular:
            return isRecording ? 170 : 160
        case .large, .extraLarge:
            return isRecording ? 190 : 180
        }
    }
    
    private var iconSize: CGFloat {
        buttonSize * 0.35
    }
    
    private var buttonGradient: LinearGradient {
        if isRecording {
            return LinearGradient(
                colors: [Color.appRecording, Color.appRecording.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if isPlaying {
            return LinearGradient(
                colors: [Color.appSuccess, Color.appSuccess.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return Color.appPrimaryGradient
        }
    }
    
    private var buttonIcon: String {
        if isRecording {
            return "stop.fill"
        } else if isPlaying {
            return "speaker.wave.2.fill"
        } else {
            return "mic.fill"
        }
    }
    
    private var accessibilityLabel: String {
        if isProcessing {
            return "Processing translation"
        } else if isRecording {
            return "Stop recording"
        } else if isPlaying {
            return "Playing translation"
        } else {
            return "Start recording"
        }
    }
    
    private var accessibilityHint: String {
        if isProcessing {
            return "Translation is being processed, please wait"
        } else if isRecording {
            return "Double tap to stop recording your voice"
        } else if isPlaying {
            return "Translation is playing"
        } else {
            return "Double tap to start recording your voice for translation"
        }
    }
    
    private func provideHapticFeedback() {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        if isRecording {
            style = .heavy
        } else if isProcessing {
            style = .light
        } else {
            style = .medium
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    private func announceStateChange() {
        let announcement: String
        if isRecording {
            announcement = "Recording stopped"
        } else {
            announcement = "Recording started"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
}

// MARK: - Accessibility Testing Helper
#if DEBUG
struct AccessibilityTestingOverlay: View {
    let isEnabled: Bool
    
    var body: some View {
        if isEnabled {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("🔍 A11y Testing")
                            .font(.caption)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        
                        Text("VoiceOver: \(UIAccessibility.isVoiceOverRunning ? "ON" : "OFF")")
                            .font(.caption2)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .padding()
                }
            }
        }
    }
}
#endif