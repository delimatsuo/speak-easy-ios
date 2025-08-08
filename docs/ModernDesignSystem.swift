//
//  ModernDesignSystem.swift
//  Mervyn Talks - Modern Design System
//
//  Comprehensive design system following iOS 17 Human Interface Guidelines
//  with proper dark/light mode support and accessibility
//

import SwiftUI

// MARK: - Modern Color System
extension Color {
    
    // MARK: - Semantic System Colors (Auto-adapting)
    
    /// Primary brand color - adapts to system appearance
    static let appPrimary = Color("AppPrimary", bundle: .main)
    
    /// Secondary brand color - adapts to system appearance  
    static let appSecondary = Color("AppSecondary", bundle: .main)
    
    /// Accent color for interactive elements
    static let appAccent = Color("AppAccent", bundle: .main)
    
    /// Background colors that adapt to light/dark mode
    static let appBackground = Color(.systemBackground)
    static let appSecondaryBackground = Color(.secondarySystemBackground)
    static let appTertiaryBackground = Color(.tertiarySystemBackground)
    
    /// Grouped background colors
    static let appGroupedBackground = Color(.systemGroupedBackground)
    static let appSecondaryGroupedBackground = Color(.secondarySystemGroupedBackground)
    static let appTertiaryGroupedBackground = Color(.tertiarySystemGroupedBackground)
    
    /// Text colors that adapt automatically
    static let appPrimaryText = Color(.label)
    static let appSecondaryText = Color(.secondaryLabel)
    static let appTertiaryText = Color(.tertiaryLabel)
    static let appQuaternaryText = Color(.quaternaryLabel)
    
    /// Separator colors
    static let appSeparator = Color(.separator)
    static let appOpaqueSeparator = Color(.opaqueSeparator)
    
    // MARK: - Semantic State Colors
    
    /// Recording state - adapts to system appearance
    static let appRecording = Color("RecordingColor", bundle: .main)
    
    /// Success/Completion state
    static let appSuccess = Color("SuccessColor", bundle: .main)
    
    /// Processing/Loading state
    static let appProcessing = Color("ProcessingColor", bundle: .main)
    
    /// Error state
    static let appError = Color("ErrorColor", bundle: .main)
    
    /// Warning state
    static let appWarning = Color("WarningColor", bundle: .main)
    
    // MARK: - Brand Gradients (Adaptive)
    
    static var appPrimaryGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [appPrimary, appSecondary]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var appBackgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                appBackground,
                appSecondaryBackground
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var appCardGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                appSecondaryBackground,
                appTertiaryBackground
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Typography System
extension Font {
    
    // MARK: - App Typography Scale
    
    /// Large title for main headings
    static let appLargeTitle = Font.largeTitle.weight(.bold)
    
    /// Title for section headers
    static let appTitle = Font.title.weight(.semibold)
    
    /// Title 2 for sub-headers
    static let appTitle2 = Font.title2.weight(.medium)
    
    /// Title 3 for smaller headers
    static let appTitle3 = Font.title3.weight(.medium)
    
    /// Headline for important content
    static let appHeadline = Font.headline.weight(.medium)
    
    /// Body text for main content
    static let appBody = Font.body
    
    /// Body text with emphasis
    static let appBodyEmphasized = Font.body.weight(.medium)
    
    /// Callout for secondary content
    static let appCallout = Font.callout
    
    /// Subheadline for metadata
    static let appSubheadline = Font.subheadline
    
    /// Footnote for additional info
    static let appFootnote = Font.footnote
    
    /// Caption for labels
    static let appCaption = Font.caption
    
    /// Caption 2 for smaller labels
    static let appCaption2 = Font.caption2
}

// MARK: - Spacing System
enum AppSpacing {
    static let xxxSmall: CGFloat = 2
    static let xxSmall: CGFloat = 4
    static let xSmall: CGFloat = 8
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48
    static let xxxLarge: CGFloat = 64
}

// MARK: - Corner Radius System
enum AppCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let button: CGFloat = 12
    static let card: CGFloat = 16
}

// MARK: - Shadow System
enum AppShadow {
    
    static let small = Shadow(
        color: Color.black.opacity(0.1),
        radius: 2,
        x: 0,
        y: 1
    )
    
    static let medium = Shadow(
        color: Color.black.opacity(0.15),
        radius: 8,
        x: 0,
        y: 4
    )
    
    static let large = Shadow(
        color: Color.black.opacity(0.2),
        radius: 16,
        x: 0,
        y: 8
    )
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

// MARK: - Modern Button Styles
struct AppPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appBodyEmphasized)
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.button)
                    .fill(isEnabled ? Color.appPrimaryGradient : Color.appSecondaryText)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .shadow(
                color: AppShadow.medium.color,
                radius: configuration.isPressed ? AppShadow.small.radius : AppShadow.medium.radius,
                x: AppShadow.medium.x,
                y: configuration.isPressed ? AppShadow.small.y : AppShadow.medium.y
            )
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appBodyEmphasized)
            .foregroundColor(.appPrimary)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.small)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.button)
                    .stroke(Color.appPrimary, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.button)
                            .fill(Color.appSecondaryBackground)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .opacity(isEnabled ? 1.0 : 0.6)
    }
}

// MARK: - Modern Card Style
struct AppCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.card)
                    .fill(Color.appSecondaryBackground)
                    .shadow(
                        color: AppShadow.small.color,
                        radius: AppShadow.small.radius,
                        x: AppShadow.small.x,
                        y: AppShadow.small.y
                    )
            )
    }
}

// MARK: - View Extensions
extension View {
    
    /// Apply modern card styling
    func appCardStyle() -> some View {
        self.modifier(AppCardStyle())
    }
    
    /// Apply primary button style
    func appPrimaryButton() -> some View {
        self.buttonStyle(AppPrimaryButtonStyle())
    }
    
    /// Apply secondary button style
    func appSecondaryButton() -> some View {
        self.buttonStyle(AppSecondaryButtonStyle())
    }
    
    /// Modern haptic feedback
    func appHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Accessibility Helpers
extension View {
    
    /// Enhanced accessibility support
    func appAccessibility(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// Dynamic type support
    func appDynamicType() -> some View {
        self
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}