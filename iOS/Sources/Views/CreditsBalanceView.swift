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
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .foregroundColor(.speakEasyPrimary)
            Text(formattedRemaining)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.speakEasyTextPrimary)
            progressBar
            Spacer()
            if credits.remainingSeconds <= 30 {
                Button(action: onBuy) { Text("Top up").font(.subheadline.weight(.semibold)) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(999)
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

private extension CreditsBalanceView {
    var progressBar: some View {
        let maxSeconds = 1800.0
        let p = min(max(0.0, Double(credits.remainingSeconds) / maxSeconds), 1.0)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.08))
                Capsule().fill(Color.speakEasyPrimary).frame(width: geo.size.width * p)
            }
        }
        .frame(width: 80, height: 6)
    }
}


