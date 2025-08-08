//
//  ResponsiveDesignPatterns.swift
//  Mervyn Talks - Responsive Design System
//
//  Modern responsive design patterns for all iPhone sizes and orientations
//

import SwiftUI

// MARK: - Device Size Categories
enum DeviceSize {
    case compact    // iPhone SE, iPhone 12 mini
    case regular    // iPhone 12, iPhone 13, iPhone 14
    case large      // iPhone 12 Pro Max, iPhone 13 Pro Max, iPhone 14 Plus
    case extraLarge // Future larger devices
    
    static var current: DeviceSize {
        let width = UIScreen.main.bounds.width
        let height = UIScreen.main.bounds.height
        let size = min(width, height) // Use smaller dimension for classification
        
        switch size {
        case ...375:
            return .compact
        case 376...390:
            return .regular
        case 391...428:
            return .large
        default:
            return .extraLarge
        }
    }
}

// MARK: - Adaptive Spacing
extension AppSpacing {
    
    /// Adaptive spacing based on device size
    static func adaptive(
        compact: CGFloat,
        regular: CGFloat? = nil,
        large: CGFloat? = nil
    ) -> CGFloat {
        let regular = regular ?? compact
        let large = large ?? regular
        
        switch DeviceSize.current {
        case .compact:
            return compact
        case .regular:
            return regular
        case .large, .extraLarge:
            return large
        }
    }
    
    /// Content padding that adapts to device size
    static var contentPadding: CGFloat {
        adaptive(compact: 16, regular: 20, large: 24)
    }
    
    /// Section spacing that adapts to device size
    static var sectionSpacing: CGFloat {
        adaptive(compact: 20, regular: 24, large: 32)
    }
    
    /// Card spacing that adapts to device size
    static var cardSpacing: CGFloat {
        adaptive(compact: 12, regular: 16, large: 20)
    }
}

// MARK: - Adaptive Font Sizes
extension Font {
    
    /// Adaptive title font
    static var appAdaptiveTitle: Font {
        switch DeviceSize.current {
        case .compact:
            return .title2.weight(.bold)
        case .regular:
            return .title.weight(.bold)
        case .large, .extraLarge:
            return .largeTitle.weight(.bold)
        }
    }
    
    /// Adaptive body font
    static var appAdaptiveBody: Font {
        switch DeviceSize.current {
        case .compact:
            return .callout
        case .regular:
            return .body
        case .large, .extraLarge:
            return .body
        }
    }
    
    /// Adaptive caption font
    static var appAdaptiveCaption: Font {
        switch DeviceSize.current {
        case .compact:
            return .caption2
        case .regular:
            return .caption
        case .large, .extraLarge:
            return .footnote
        }
    }
}

// MARK: - Responsive Layout Helper
struct ResponsiveLayout: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    let compactContent: () -> AnyView
    let regularContent: () -> AnyView
    
    func body(content: Content) -> some View {
        Group {
            if horizontalSizeClass == .compact {
                compactContent()
            } else {
                regularContent()
            }
        }
    }
}

extension View {
    func responsiveLayout<Compact: View, Regular: View>(
        @ViewBuilder compact: @escaping () -> Compact,
        @ViewBuilder regular: @escaping () -> Regular
    ) -> some View {
        self.modifier(ResponsiveLayout(
            compactContent: { AnyView(compact()) },
            regularContent: { AnyView(regular()) }
        ))
    }
}

// MARK: - Adaptive Button Sizes
enum ButtonSize {
    case small
    case medium
    case large
    
    var minHeight: CGFloat {
        switch DeviceSize.current {
        case .compact:
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        case .regular:
            switch self {
            case .small: return 36
            case .medium: return 48
            case .large: return 60
            }
        case .large, .extraLarge:
            switch self {
            case .small: return 40
            case .medium: return 52
            case .large: return 64
            }
        }
    }
    
    var horizontalPadding: CGFloat {
        switch DeviceSize.current {
        case .compact:
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 24
            }
        case .regular:
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 28
            }
        case .large, .extraLarge:
            switch self {
            case .small: return 20
            case .medium: return 24
            case .large: return 32
            }
        }
    }
}

// MARK: - Responsive Grid System
struct ResponsiveGrid<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: () -> Content
    
    init(
        columns: Int = 2,
        spacing: CGFloat = AppSpacing.medium,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }
    
    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: adaptiveColumns)
    }
    
    private var adaptiveColumns: Int {
        switch DeviceSize.current {
        case .compact:
            return max(1, columns - 1)
        case .regular:
            return columns
        case .large, .extraLarge:
            return columns + 1
        }
    }
    
    var body: some View {
        LazyVGrid(columns: gridItems, spacing: spacing) {
            content()
        }
    }
}

// MARK: - Safe Area Responsive Padding
extension View {
    
    /// Apply responsive padding that considers safe areas and device size
    func responsivePadding() -> some View {
        self
            .padding(.horizontal, AppSpacing.contentPadding)
            .padding(.vertical, AppSpacing.cardSpacing)
    }
    
    /// Apply responsive section spacing
    func responsiveSectionSpacing() -> some View {
        self
            .padding(.vertical, AppSpacing.sectionSpacing)
    }
}

// MARK: - Orientation-Aware Layouts
struct OrientationAwareLayout: ViewModifier {
    @State private var orientation = UIDeviceOrientation.unknown
    
    let portraitContent: () -> AnyView
    let landscapeContent: () -> AnyView
    
    func body(content: Content) -> some View {
        Group {
            if orientation.isPortrait || orientation == .unknown {
                portraitContent()
            } else {
                landscapeContent()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            orientation = UIDevice.current.orientation
        }
        .onAppear {
            orientation = UIDevice.current.orientation
        }
    }
}

extension View {
    func orientationAware<Portrait: View, Landscape: View>(
        @ViewBuilder portrait: @escaping () -> Portrait,
        @ViewBuilder landscape: @escaping () -> Landscape
    ) -> some View {
        self.modifier(OrientationAwareLayout(
            portraitContent: { AnyView(portrait()) },
            landscapeContent: { AnyView(landscape()) }
        ))
    }
}

// MARK: - Dynamic Island Safe Area
extension View {
    
    /// Handle Dynamic Island safe areas properly
    func dynamicIslandSafeArea() -> some View {
        self
            .padding(.top, hasDynamicIsland ? 8 : 0)
    }
    
    private var hasDynamicIsland: Bool {
        guard let window = UIApplication.shared.windows.first else { return false }
        return window.safeAreaInsets.top > 47 // Dynamic Island devices have larger top inset
    }
}

// MARK: - Accessibility-Aware Responsive Design
extension View {
    
    /// Adjust layout based on accessibility settings
    func accessibilityResponsive() -> some View {
        self
            .dynamicTypeSize(.large...DynamicTypeSize.accessibility2)
            .modifier(AccessibilityResponsiveModifier())
    }
}

struct AccessibilityResponsiveModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityInvertColors) var invertColors
    
    func body(content: Content) -> some View {
        content
            .animation(
                reduceMotion ? .none : .easeInOut(duration: 0.3),
                value: dynamicTypeSize
            )
            .foregroundColor(
                invertColors ? .primary : nil
            )
    }
}