//
//  UsageStatisticsView.swift
//  Mervyn Talks
//
//  Displays translation usage statistics for the minutes-based payment model
//

import SwiftUI

// Minimal wrapper view to avoid conflicts and deprecated responsive utilities
struct UsageStatisticsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Usage Statistics")
                .font(.title2)
                .bold()
            Text("View detailed usage from the home screen card.")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct UsageStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        UsageStatisticsView()
    }
}
