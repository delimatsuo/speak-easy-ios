//
//  ResponsiveHelper.swift
//  Mervyn Talks - Responsive Design Helper
//
//  Simple responsive utilities for immediate implementation
//

import SwiftUI

struct ResponsiveHelper {
    
    // MARK: - Device Size Detection
    
    enum DeviceSize {
        case compact    // iPhone SE, iPhone 12 mini
        case regular    // iPhone 12, iPhone 13, iPhone 14
        case large      // iPhone 12 Pro Max, iPhone 13 Pro Max, iPhone 14 Plus
        
        static var current: DeviceSize {
            let width = UIScreen.main.bounds.width
            switch width {
            case ...375:
                return .compact
            case 376...390:
                return .regular
            default:
                return .large
            }
        }
    }
    
    // MARK: - Adaptive Sizes
    
    /// Adaptive microphone button size
    static var microphoneButtonSize: CGFloat {
        switch DeviceSize.current {
        case .compact:
            return 130
        case .regular:
            return 150
        case .large:
            return 170
        }
    }
    
    /// Adaptive pulse animation size
    static var pulseAnimationSize: CGFloat {
        microphoneButtonSize + 30
    }
    
    /// Adaptive content padding
    static var contentPadding: CGFloat {
        switch DeviceSize.current {
        case .compact:
            return 16
        case .regular:
            return 20
        case .large:
            return 24
        }
    }
    
    /// Adaptive section spacing
    static var sectionSpacing: CGFloat {
        switch DeviceSize.current {
        case .compact:
            return 16
        case .regular:
            return 20
        case .large:
            return 24
        }
    }
    
    // MARK: - Safe Area Support
    
    /// Check if device has Dynamic Island
    static var hasDynamicIsland: Bool {
        if #available(iOS 16.0, *) {
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
            return window?.safeAreaInsets.top ?? 0 > 50
        }
        return false
    }
}

// MARK: - View Extensions for Responsive Design

extension View {
    
    /// Apply responsive padding
    func responsivePadding() -> some View {
        self.padding(.horizontal, ResponsiveHelper.contentPadding)
    }
    
    /// Apply responsive section spacing
    func responsiveSectionSpacing() -> some View {
        self.padding(.vertical, ResponsiveHelper.sectionSpacing)
    }
    
    /// Apply minimum touch target size for accessibility
    func minimumTouchTarget() -> some View {
        self.frame(minWidth: 44, minHeight: 44)
    }
}

// MARK: - Adaptive Fonts

extension Font {
    
    /// Responsive headline font
    static var responsiveHeadline: Font {
        switch ResponsiveHelper.DeviceSize.current {
        case .compact:
            return .headline
        case .regular:
            return .title3.weight(.semibold)
        case .large:
            return .title2.weight(.semibold)
        }
    }
    
    /// Responsive caption font
    static var responsiveCaption: Font {
        switch ResponsiveHelper.DeviceSize.current {
        case .compact:
            return .caption2
        case .regular:
            return .caption
        case .large:
            return .footnote
        }
    }
}