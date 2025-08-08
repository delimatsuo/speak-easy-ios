//
//  CreditsBalanceView.swift
//  Mervyn Talks
//
//  Displays remaining credit time and low-balance prompts.
//

import SwiftUI

struct CreditsBalanceView: View {
    @ObservedObject var credits = CreditsManager.shared
    var onBuy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.speakEasyPrimary)
                Text(formattedRemaining)
                    .font(.headline)
                    .foregroundColor(.speakEasyTextPrimary)
                Spacer()
                Button(action: onBuy) {
                    Text("Buy minutes")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.speakEasyPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .accessibilityIdentifier("buyMinutesButton")
            }

            if credits.remainingSeconds <= 60 && credits.remainingSeconds > 0 {
                Text("Low balance: \(format(seconds: credits.remainingSeconds)). Consider topping up.")
                    .font(.caption)
                    .foregroundColor(credits.remainingSeconds <= 15 ? .red : .speakEasyTextSecondary)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var formattedRemaining: String {
        "\(format(seconds: credits.remainingSeconds)) remaining"
    }

    private func format(seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}


