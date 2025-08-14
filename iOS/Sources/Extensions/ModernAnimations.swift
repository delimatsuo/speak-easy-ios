//
//  ModernAnimations.swift
//  Mervyn Talks
//
//  Modern iOS 17 spring animations and transitions
//  Provides consistent, smooth animations throughout the app
//

import SwiftUI

// MARK: - Modern Animation Presets

struct ModernAnimations {
    
    // MARK: - Spring Animations
    
    /// Gentle spring animation for UI state changes
    static let gentle = Animation.spring(
        response: 0.6,
        dampingFraction: 0.8,
        blendDuration: 0.1
    )
    
    /// Bouncy spring animation for interactive elements
    static let bouncy = Animation.spring(
        response: 0.4,
        dampingFraction: 0.7,
        blendDuration: 0.1
    )
    
    /// Snappy spring animation for quick interactions
    static let snappy = Animation.spring(
        response: 0.3,
        dampingFraction: 0.9,
        blendDuration: 0.05
    )
    
    /// Smooth spring animation for seamless transitions
    static let smooth = Animation.spring(
        response: 0.8,
        dampingFraction: 1.0,
        blendDuration: 0.1
    )
    
    // MARK: - Easing Animations
    
    /// Smooth ease-in-out for general purpose animations
    static let easeInOut = Animation.easeInOut(duration: 0.4)
    
    /// Quick ease-in-out for fast interactions
    static let quickEaseInOut = Animation.easeInOut(duration: 0.2)
    
    /// Slow ease-in-out for dramatic effects
    static let slowEaseInOut = Animation.easeInOut(duration: 0.8)
    
    // MARK: - Specialized Animations
    
    /// Pulse animation for recording states
    static let pulse = Animation.easeInOut(duration: 0.8)
        .repeatForever(autoreverses: true)
    
    /// Breathing animation for subtle emphasis
    static let breathing = Animation.easeInOut(duration: 1.2)
        .repeatForever(autoreverses: true)
    
    /// Wave animation for loading states
    static func wave(delay: Double = 0) -> Animation {
        Animation.easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
            .delay(delay)
    }
    
    /// Rotation animation with spring physics
    static let springRotation = Animation.spring(
        response: 0.5,
        dampingFraction: 0.6,
        blendDuration: 0.1
    )
}

// MARK: - Animation View Modifiers

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false
    let isActive: Bool
    let scale: CGFloat
    let opacity: CGFloat
    
    init(isActive: Bool, scale: CGFloat = 1.1, opacity: CGFloat = 0.6) {
        self.isActive = isActive
        self.scale = scale
        self.opacity = opacity
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && isPulsing ? scale : 1.0)
            .opacity(isActive ? (isPulsing ? opacity : 1.0) : 1.0)
            .animation(ModernAnimations.pulse, value: isPulsing)
            .onAppear {
                if isActive {
                    isPulsing = true
                }
            }
            .onChange(of: isActive) { newValue in
                isPulsing = newValue
            }
    }
}

struct BreathingEffect: ViewModifier {
    @State private var isBreathing = false
    let isActive: Bool
    let scale: CGFloat
    
    init(isActive: Bool, scale: CGFloat = 1.05) {
        self.isActive = isActive
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive && isBreathing ? scale : 1.0)
            .animation(ModernAnimations.breathing, value: isBreathing)
            .onAppear {
                if isActive {
                    isBreathing = true
                }
            }
            .onChange(of: isActive) { newValue in
                isBreathing = newValue
            }
    }
}

struct SpringPressEffect: ViewModifier {
    @State private var isPressed = false
    let pressedScale: CGFloat
    
    init(pressedScale: CGFloat = 0.95) {
        self.pressedScale = pressedScale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressedScale : 1.0)
            .animation(ModernAnimations.snappy, value: isPressed)
            .onTapGesture {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                // Visual feedback
                withAnimation(ModernAnimations.snappy) {
                    isPressed = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(ModernAnimations.snappy) {
                        isPressed = false
                    }
                }
            }
    }
}

struct FloatingEffect: ViewModifier {
    @State private var isFloating = false
    let offset: CGFloat
    
    init(offset: CGFloat = -5) {
        self.offset = offset
    }
    
    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? offset : 0)
            .animation(ModernAnimations.breathing, value: isFloating)
            .onAppear {
                isFloating = true
            }
    }
}

struct ShakeEffect: ViewModifier {
    @State private var shakeOffset: CGFloat = 0
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: isActive) { newValue in
                if newValue {
                    performShake()
                }
            }
    }
    
    private func performShake() {
        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.error)
        
        withAnimation(Animation.linear(duration: 0.1).repeatCount(6, autoreverses: true)) {
            shakeOffset = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            shakeOffset = 0
        }
    }
}

// MARK: - Transition Effects

struct SlideInTransition: ViewModifier {
    let edge: Edge
    let distance: CGFloat
    
    init(from edge: Edge = .bottom, distance: CGFloat = 100) {
        self.edge = edge
        self.distance = distance
    }
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: edge).combined(with: .opacity),
                removal: .move(edge: edge).combined(with: .opacity)
            ))
    }
}

struct ScaleInTransition: ViewModifier {
    let scale: CGFloat
    
    init(scale: CGFloat = 0.3) {
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .scale(scale: scale).combined(with: .opacity),
                removal: .scale(scale: scale).combined(with: .opacity)
            ))
    }
}

// MARK: - Complex Animation Sequences

struct RecordingAnimationSequence: View {
    let isActive: Bool
    let size: CGFloat
    
    @State private var pulsePhase = 0.0
    @State private var waveOffsets: [CGFloat]
    
    init(isActive: Bool, size: CGFloat) {
        self.isActive = isActive
        self.size = size
        self._waveOffsets = State(initialValue: Array(repeating: 0, count: 20))
    }
    
    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(Color(red: 0.95, green: 0.26, blue: 0.21).opacity(0.3), lineWidth: 2)
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(isActive ? 1.2 : 1.0)
                .opacity(isActive ? 0.5 : 0.0)
                .animation(ModernAnimations.pulse, value: isActive)
            
            // Middle pulse ring
            Circle()
                .stroke(Color(red: 0.95, green: 0.26, blue: 0.21).opacity(0.5), lineWidth: 3)
                .frame(width: size * 1.3, height: size * 1.3)
                .scaleEffect(isActive ? 1.1 : 1.0)
                .opacity(isActive ? 0.7 : 0.0)
                .animation(ModernAnimations.pulse.delay(0.2), value: isActive)
            
            // Wave visualization
            if isActive {
                HStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.speakEasyRecording)
                            .frame(width: 2, height: 4 + waveOffsets[index])
                            .animation(
                                ModernAnimations.wave(delay: Double(index) * 0.05),
                                value: waveOffsets[index]
                            )
                    }
                }
                .onAppear {
                    startWaveAnimation()
                }
            }
        }
    }
    
    private func startWaveAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard isActive else { return }
            
            for i in waveOffsets.indices {
                waveOffsets[i] = CGFloat.random(in: 5...25)
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    func pulseEffect(isActive: Bool, scale: CGFloat = 1.1, opacity: CGFloat = 0.6) -> some View {
        modifier(PulseEffect(isActive: isActive, scale: scale, opacity: opacity))
    }
    
    func breathingEffect(isActive: Bool = true, scale: CGFloat = 1.05) -> some View {
        modifier(BreathingEffect(isActive: isActive, scale: scale))
    }
    
    func springPressEffect(pressedScale: CGFloat = 0.95) -> some View {
        modifier(SpringPressEffect(pressedScale: pressedScale))
    }
    
    func floatingEffect(offset: CGFloat = -5) -> some View {
        modifier(FloatingEffect(offset: offset))
    }
    
    func shakeEffect(isActive: Bool) -> some View {
        modifier(ShakeEffect(isActive: isActive))
    }
    
    func slideInTransition(from edge: Edge = .bottom, distance: CGFloat = 100) -> some View {
        self.transition(.move(edge: edge).combined(with: .opacity))
    }
    
    func scaleInTransition(scale: CGFloat = 0.3) -> some View {
        modifier(ScaleInTransition(scale: scale))
    }
    
    // Convenience animation methods
    func animateOnTap<T: Equatable>(value: T, animation: Animation = ModernAnimations.snappy) -> some View {
        self.animation(animation, value: value)
    }
    
    func gentleAnimation<T: Equatable>(value: T) -> some View {
        self.animation(ModernAnimations.gentle, value: value)
    }
    
    func bouncyAnimation<T: Equatable>(value: T) -> some View {
        self.animation(ModernAnimations.bouncy, value: value)
    }
    
    func smoothAnimation<T: Equatable>(value: T) -> some View {
        self.animation(ModernAnimations.smooth, value: value)
    }
}

// MARK: - Haptic Feedback Integration

struct HapticFeedback {
    
    static func light() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    static func medium() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    static func heavy() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    static func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    static func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    static func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    static func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}

// MARK: - Preview

#if DEBUG
struct ModernAnimations_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            Circle()
                .fill(Color.blue)
                .frame(width: 100, height: 100)
                .pulseEffect(isActive: true)
            
            Rectangle()
                .fill(Color.green)
                .frame(width: 150, height: 50)
                .breathingEffect()
                .cornerRadius(12)
            
            Button("Press Me") {
                HapticFeedback.success()
            }
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(12)
            .springPressEffect()
            
            RecordingAnimationSequence(isActive: true, size: 80)
        }
        .padding()
    }
}
#endif