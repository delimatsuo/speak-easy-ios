//
//  SignInView.swift
//  Mervyn Talks
//
//  Required sign-in gate with Apple sign-in (Google can be added later).
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var auth = AuthViewModel.shared

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Welcome to Mervyn Talks")
                    .font(.title.bold())
                Text("We do not retain your conversations. Your voice/text is used only to perform translation in real time, then purged when the session ends. Purchase and session metadata (no conversation content) may be stored to manage credits and support.")
                    .font(.subheadline)
                    .foregroundColor(.speakEasyTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            SignInWithAppleButton()

            if let error = auth.lastError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
        .padding()
    }
}

private struct SignInWithAppleButton: View {
    @StateObject private var auth = AuthViewModel.shared
    var body: some View {
        Button(action: { auth.startSignInWithApple() }) {
            HStack {
                Image(systemName: "apple.logo")
                Text("Sign in with Apple")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .accessibilityIdentifier("signInWithAppleButton")
        .padding(.horizontal)
    }
}


