//
//  AccessibilitySupport.swift
//  Mervyn Talks
//
//  Comprehensive accessibility support for iOS 17
//  VoiceOver, Dynamic Type, and accessibility best practices
//

import SwiftUI
import UIKit

// MARK: - Accessibility Configuration

struct AccessibilityConfig {
    
    // MARK: - Voice Over Labels
    
    struct Labels {
        static let microphoneButton = "Record translation"
        static let microphoneButtonHint = "Double tap to start recording your voice for translation"
        static let microphoneButtonRecording = "Stop recording"
        static let microphoneButtonRecordingHint = "Double tap to stop recording and process translation"
        
        static let languagePickerSource = "Source language selector"
        static let languagePickerTarget = "Target language selector"
        static let languagePickerHint = "Double tap to select language for translation"
        
        static let swapLanguagesButton = "Swap languages"
        static let swapLanguagesHint = "Double tap to swap source and target languages"
        
        static let replayButton = "Replay translation"
        static let replayButtonHint = "Double tap to replay the audio translation"
        
        static let historyButton = "Translation history"
        static let historyButtonHint = "Double tap to view previous translations"
        
        static let connectionTestButton = "Test connection"
        static let connectionTestButtonHint = "Double tap to test connection to translation services"
        
        static let usageStatsButton = "Usage statistics"
        static let usageStatsButtonHint = "Double tap to view detailed usage statistics"
        
        static let cancelButton = "Cancel translation"
        static let cancelButtonHint = "Double tap to cancel the current translation request"
    }
    
    // MARK: - Voice Over Values
    
    struct Values {
        static func recordingDuration(_ duration: Int) -> String {
            let minutes = duration / 60
            let seconds = duration % 60
            return "Recording duration: \(minutes) minutes and \(seconds) seconds"
        }
        
        static func languageSelection(_ language: String) -> String {
            return "Selected language: \(language)"
        }
        
        static func translationProgress(_ status: String) -> String {
            return "Translation status: \(status)"
        }
        
        static func usageRemaining(_ minutes: Double) -> String {
            return String(format: "%.1f minutes remaining", minutes)
        }
    }
    
    // MARK: - Voice Over Traits
    
    struct Traits {
        static let primaryButton: AccessibilityTraits = [.isButton, .startsMediaSession]
        static let secondaryButton: AccessibilityTraits = .isButton
        static let picker: AccessibilityTraits = .isButton
        static let statisticValue: AccessibilityTraits = .isStaticText
        static let heading: AccessibilityTraits = .isHeader
    }
}

// MARK: - Dynamic Type Support

struct DynamicTypeSupport {
    
    /// Returns appropriate font for accessibility
    static func font(for style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        if #available(iOS 16.0, *) {
            return Font.system(style, design: .default, weight: weight)
        } else {
            // For iOS 15 and earlier, use simpler approach
            switch weight {
            case .bold, .heavy, .black:
                return Font.system(style).bold()
            case .semibold, .medium:
                return Font.system(style).weight(.semibold)
            default:
                return Font.system(style)
            }
        }
    }
    
    /// Returns scaled value based on dynamic type setting
    static func scaledValue(_ baseValue: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> CGFloat {
        let scaleFactor = UIFontMetrics(forTextStyle: UIFont.TextStyle.from(textStyle)).scaledValue(for: 1.0)
        return baseValue * scaleFactor
    }
    
    /// Returns appropriate spacing that scales with dynamic type
    static func scaledSpacing(_ baseSpacing: CGFloat) -> CGFloat {
        return scaledValue(baseSpacing, relativeTo: .body)
    }
    
    /// Checks if accessibility sizes are enabled
    static var isAccessibilitySize: Bool {
        UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
    }
    
    /// Returns minimum touch target size (44x44 points)
    static let minimumTouchTarget: CGFloat = 44
}

// MARK: - VoiceOver Navigation Support

struct VoiceOverSupport {
    
    /// Creates accessible group for related elements
    static func accessibilityElement<Content: View>(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = .isStaticText,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// Creates accessible button with proper traits
    static func accessibleButton<Content: View>(
        label: String,
        hint: String,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .accessibilityAddTraits(.isButton)
        .frame(minWidth: DynamicTypeSupport.minimumTouchTarget, minHeight: DynamicTypeSupport.minimumTouchTarget)
    }
    
    /// Creates accessible picker with proper traits
    static func accessiblePicker<SelectionValue: Hashable, Content: View>(
        selection: Binding<SelectionValue>,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Picker(selection: selection, label: Text(label)) {
            content()
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Accessibility View Modifiers

struct AccessibleMicrophoneButton: ViewModifier {
    let isRecording: Bool
    let isProcessing: Bool
    let isPlaying: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(isRecording ? 
                AccessibilityConfig.Labels.microphoneButtonRecording : 
                AccessibilityConfig.Labels.microphoneButton)
            .accessibilityHint(isRecording ? 
                AccessibilityConfig.Labels.microphoneButtonRecordingHint : 
                AccessibilityConfig.Labels.microphoneButtonHint)
            .accessibilityAddTraits(AccessibilityConfig.Traits.primaryButton)
            .accessibilityRemoveTraits(isProcessing || isPlaying ? .isButton : [])
            .frame(minWidth: DynamicTypeSupport.minimumTouchTarget, 
                   minHeight: DynamicTypeSupport.minimumTouchTarget)
    }
}

struct AccessibleLanguagePicker: ViewModifier {
    let isSource: Bool
    let selectedLanguage: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(isSource ? 
                AccessibilityConfig.Labels.languagePickerSource : 
                AccessibilityConfig.Labels.languagePickerTarget)
            .accessibilityValue(AccessibilityConfig.Values.languageSelection(selectedLanguage))
            .accessibilityHint(AccessibilityConfig.Labels.languagePickerHint)
            .accessibilityAddTraits(AccessibilityConfig.Traits.picker)
            .frame(minHeight: DynamicTypeSupport.minimumTouchTarget)
    }
}

struct AccessibleSwapButton: ViewModifier {
    let isDisabled: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(AccessibilityConfig.Labels.swapLanguagesButton)
            .accessibilityHint(AccessibilityConfig.Labels.swapLanguagesHint)
            .accessibilityAddTraits(AccessibilityConfig.Traits.secondaryButton)
            .accessibilityRemoveTraits(isDisabled ? .isButton : [])
            .frame(minWidth: DynamicTypeSupport.minimumTouchTarget, 
                   minHeight: DynamicTypeSupport.minimumTouchTarget)
    }
}

struct AccessibleStatistic: ViewModifier {
    let label: String
    let value: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel("\(label): \(value)")
            .accessibilityAddTraits(AccessibilityConfig.Traits.statisticValue)
    }
}

struct AccessibleCard: ViewModifier {
    let title: String
    let content: String
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title): \(content)")
            .accessibilityAddTraits(AccessibilityConfig.Traits.statisticValue)
    }
}

// MARK: - Reduced Motion Support

struct ReducedMotionSupport {
    
    /// Checks if user has reduced motion enabled
    static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    /// Returns animation or nil based on reduce motion setting
    static func animation(_ animation: Animation) -> Animation? {
        return isReduceMotionEnabled ? nil : animation
    }
    
    /// Returns appropriate animation duration
    static func duration(_ baseDuration: Double) -> Double {
        return isReduceMotionEnabled ? 0 : baseDuration
    }
}

struct MotionSensitiveAnimation<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    
    func body(content: Content) -> some View {
        if ReducedMotionSupport.isReduceMotionEnabled {
            content
        } else {
            content.animation(animation, value: value)
        }
    }
}

// MARK: - High Contrast Support

struct HighContrastSupport {
    
    /// Checks if high contrast is enabled
    static var isDarkerSystemColorsEnabled: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    /// Checks if increase contrast is enabled
    static var isIncreaseContrastEnabled: Bool {
        // UIAccessibility.isIncreaseContrastEnabled is not available on iOS
        // Use isDarkerSystemColorsEnabled as a proxy for high contrast needs
        UIAccessibility.isDarkerSystemColorsEnabled
    }
    
    /// Returns appropriate colors for high contrast mode
    static func adaptiveColor(
        normal: Color,
        highContrast: Color
    ) -> Color {
        return isIncreaseContrastEnabled ? highContrast : normal
    }
}

// MARK: - View Extensions

extension View {
    func accessibleMicrophoneButton(isRecording: Bool, isProcessing: Bool, isPlaying: Bool) -> some View {
        modifier(AccessibleMicrophoneButton(
            isRecording: isRecording,
            isProcessing: isProcessing,
            isPlaying: isPlaying
        ))
    }
    
    func accessibleLanguagePicker(isSource: Bool, selectedLanguage: String) -> some View {
        modifier(AccessibleLanguagePicker(
            isSource: isSource,
            selectedLanguage: selectedLanguage
        ))
    }
    
    func accessibleSwapButton(isDisabled: Bool) -> some View {
        modifier(AccessibleSwapButton(isDisabled: isDisabled))
    }
    
    func accessibleStatistic(label: String, value: String) -> some View {
        modifier(AccessibleStatistic(label: label, value: value))
    }
    
    func accessibleCard(title: String, content: String) -> some View {
        modifier(AccessibleCard(title: title, content: content))
    }
    
    func motionSensitiveAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionSensitiveAnimation(animation: animation, value: value))
    }
    
    /// Applies accessibility-friendly minimum touch target
    func accessibleTouchTarget() -> some View {
        self.frame(minWidth: DynamicTypeSupport.minimumTouchTarget,
                   minHeight: DynamicTypeSupport.minimumTouchTarget)
    }
    
    /// Makes text respect dynamic type scaling
    func dynamicTypeSize() -> some View {
        self.font(DynamicTypeSupport.font(for: .body))
    }
    
    /// Creates accessible heading
    func accessibleHeading(_ level: AccessibilityHeadingLevel = .h2) -> some View {
        self.accessibilityAddTraits(.isHeader)
            .accessibilityHeading(level)
    }
}

// MARK: - UIFont Extension for Dynamic Type

extension UIFont.TextStyle {
    static func from(_ textStyle: Font.TextStyle) -> UIFont.TextStyle {
        switch textStyle {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .caption: return .caption1
        case .caption2: return .caption2
        case .footnote: return .footnote
        case .subheadline: return .subheadline
        @unknown default: return .body
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AccessibilitySupport_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Accessibility Demo")
                .font(DynamicTypeSupport.font(for: .largeTitle, weight: .bold))
                .accessibleHeading(.h1)
            
            VoiceOverSupport.accessibleButton(
                label: AccessibilityConfig.Labels.microphoneButton,
                hint: AccessibilityConfig.Labels.microphoneButtonHint,
                action: { HapticFeedback.light() }
            ) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "mic.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    )
            }
            
            Text("Sample statistic")
                .accessibleStatistic(label: "Usage", value: "45.2 minutes")
            
            Text("Dynamic Type support makes text scale appropriately for all users")
                .dynamicTypeSize()
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
    }
}
#endif