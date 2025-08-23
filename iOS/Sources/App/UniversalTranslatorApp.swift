//
//  UniversalTranslatorApp.swift
//  UniversalTranslator
//
//  Main app entry point for iOS
//

import SwiftUI

@main
struct UniversalTranslatorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            RootGateView()
        }
    }
}

private struct RootGateView: View {
    @AppStorage("hasAcceptedPolicies") private var hasAcceptedPolicies = false

    var body: some View {
        if hasAcceptedPolicies {
            ContentView()
        } else {
            FirstRunConsentView()
        }
    }
}

private struct FirstRunConsentView: View {
    @AppStorage("hasAcceptedPolicies") private var hasAcceptedPolicies = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Text("Welcome to Universal AI Translator")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    
                    Text("We keep things private: we don't store conversations; only minimal purchase and session metadata for up to 12 months.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                    
                    // Weekly free credit info
                    HStack(spacing: 8) {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                        
                        Text("Get 1 free minute of translation every Monday!")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                
                VStack(spacing: 12) {
                    NavigationLink {
                        LegalDocumentView(resourceName: "TERMS_OF_USE", title: "Terms of Use")
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Terms of Use")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                    
                    NavigationLink {
                        LegalDocumentView(resourceName: "PRIVACY_POLICY", title: "Privacy Policy")
                    } label: {
                        HStack {
                            Image(systemName: "lock.doc")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Text("By continuing, you agree to our Terms of Use and Privacy Policy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: { hasAcceptedPolicies = true }) {
                        Text("Agree and Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(24)
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
