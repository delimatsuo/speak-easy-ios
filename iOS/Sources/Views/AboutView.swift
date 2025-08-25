//
//  AboutView.swift
//  UniversalTranslator
//
//  Information about the app and credit system
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var anonymousCredits = AnonymousCreditsManager.shared
    
    private var nextResetDate: String {
        if let resetDate = anonymousCredits.nextResetDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: resetDate)
        }
        return "next Monday"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // App Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About Universal AI Translator", systemImage: "info.circle.fill")
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        Text("Your personal translator powered by advanced AI. Speak naturally in any language and get instant, accurate translations.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Credit System Section
                    VStack(alignment: .leading, spacing: 16) {
                        Label("How Credits Work", systemImage: "clock.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Free weekly credit
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Free Weekly Credit")
                                        .font(.subheadline.bold())
                                    Text("Get 1 free minute of translation every Monday. Perfect for trying the app or occasional use!")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if anonymousCredits.remainingSeconds < 60 {
                                        Text("Next reset: \(nextResetDate)")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Purchase options
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "cart.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Purchase Credits")
                                        .font(.subheadline.bold())
                                    Text("Need more translation time? Purchase additional minutes anytime:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("• 5 minutes - $1.99")
                                        Text("• 10 minutes - $2.99")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            // How credits are used
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "mic.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Credit Usage")
                                        .font(.subheadline.bold())
                                    Text("Credits are deducted based on actual translation time. Unused credits never expire.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Features Section
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Features", systemImage: "star.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(icon: "globe", title: "20+ Languages", description: "Translate between major world languages")
                            FeatureRow(icon: "waveform", title: "Real-time Translation", description: "Speak naturally and get instant results")
                            FeatureRow(icon: "applewatch", title: "Apple Watch Support", description: "Translate on the go from your wrist")
                            FeatureRow(icon: "lock.fill", title: "Privacy First", description: "No conversation storage, minimal data collection")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Version info
                    HStack {
                        Spacer()
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    AboutView()
}