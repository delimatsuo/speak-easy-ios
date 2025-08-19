//
//  LaunchScreen.swift
//  UniversalTranslator
//
//  Launch screen matching app icon design
//

import SwiftUI

struct LaunchScreen: View {
    @State private var animationScale = 0.8
    @State private var animationOpacity = 0.0
    
    var body: some View {
        ZStack {
            // Background gradient matching icon
            Color.speakEasyBackgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // App Icon
                SpeakEasyIcon(size: 200)
                    .scaleEffect(animationScale)
                    .opacity(animationOpacity)
                
                // App Name
                Text("Universal AI Translator")
                    .font(.system(size: 42, weight: .medium, design: .rounded))
                    .foregroundColor(.speakEasyTextPrimary)
                    .opacity(animationOpacity)
                
                // Tagline
                Text("Voice Translation Made Simple")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(.speakEasyTextSecondary)
                    .opacity(animationOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animationScale = 1.0
                animationOpacity = 1.0
            }
        }
    }
}

struct LaunchScreen_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreen()
    }
}