//
//  UsageStatisticsView.swift
//  Mervyn Talks
//
//  Displays translation usage statistics for the minutes-based payment model
//

import SwiftUI

struct UsageStatisticsView: View {
    @StateObject private var usageService = UsageTrackingService.shared
    @State private var showingFullStats = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Usage Status Bar
            HStack(spacing: 10) {
                // Beta Badge (only visible during beta)
                if usageService.isUnlimitedBeta {
                    Text("BETA")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                
                // Usage display - changes based on beta/paid status
                if usageService.isUnlimitedBeta {
                    Text("Unlimited minutes during beta")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: { showingFullStats.toggle() }) {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // For future paid mode
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", usageService.minutesRemainingForDisplay)) min remaining")
                            .font(.footnote)
                            .fontWeight(.medium)
                        
                        // Progress bar showing usage
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: geometry.size.width, height: 4)
                                
                                // Foreground - usage indicator
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(usageWarningColor)
                                    .frame(width: geometry.size.width * usageService.minutesUsedPercentage(), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    
                    Spacer()
                    
                    // Buy more minutes button (for future paid mode)
                    if !usageService.isUnlimitedBeta && usageService.shouldShowLowMinutesWarning() {
                        Button(action: {
                            // Will be implemented in paid version
                            // For now just show the stats
                            showingFullStats = true
                        }) {
                            Text("Add Minutes")
                                .font(.footnote)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button(action: { showingFullStats.toggle() }) {
                        Image(systemName: "chart.bar")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .sheet(isPresented: $showingFullStats) {
            UsageDetailView()
        }
    }
    
    // Color changes based on remaining minutes
    private var usageWarningColor: Color {
        if usageService.minutesRemainingForDisplay > 10 {
            return Color.blue
        } else if usageService.minutesRemainingForDisplay > 5 {
            return Color.orange
        } else {
            return Color.red
        }
    }
}

struct UsageDetailView: View {
    @StateObject private var usageService = UsageTrackingService.shared
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("CURRENT USAGE")) {
                    if usageService.isUnlimitedBeta {
                        HStack {
                            Text("Beta Status")
                            Spacer()
                            Text("Unlimited")
                                .foregroundColor(.blue)
                        }
                    } else {
                        HStack {
                            Text("Minutes Remaining")
                            Spacer()
                            Text("\(String(format: "%.1f", usageService.minutesRemainingForDisplay))")
                                .foregroundColor(usageService.minutesRemainingForDisplay > 5 ? .blue : .red)
                        }
                    }
                    
                    HStack {
                        Text("Minutes Used")
                        Spacer()
                        Text("\(String(format: "%.1f", usageService.totalMinutesUsed))")
                            .foregroundColor(.secondary)
                    }
                    
                    if usageService.isSessionActive {
                        HStack {
                            Text("Current Session")
                            Spacer()
                            Text(usageService.currentSessionStartTime != nil ? 
                                 usageService.formatTime(seconds: Date().timeIntervalSince(usageService.currentSessionStartTime!)) : "0:00")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section(header: Text("STATISTICS")) {
                    HStack {
                        Text("Sessions Today")
                        Spacer()
                        Text("\(usageService.sessionsToday)")
                    }
                    
                    HStack {
                        Text("Sessions This Week")
                        Spacer()
                        Text("\(usageService.sessionsThisWeek)")
                    }
                    
                    HStack {
                        Text("Average Session Length")
                        Spacer()
                        Text("\(String(format: "%.1f", usageService.averageSessionLength)) min")
                    }
                }
                
                if !usageService.isUnlimitedBeta {
                    Section(header: Text("ESTIMATE")) {
                        HStack {
                            Text("Estimated Sessions Left")
                            Spacer()
                            Text("\(usageService.estimatedRemainingSessionsAtCurrentRate())")
                        }
                    }
                }
                
                // Beta Information
                if usageService.isUnlimitedBeta {
                    Section(header: Text("BETA INFORMATION")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You're using the Mervyn Talks beta")
                                .font(.headline)
                            
                            Text("During the beta period, you have unlimited translation minutes. After the beta period, Mervyn Talks will transition to a pay-per-minute model.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Usage Statistics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct UsageStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            UsageStatisticsView()
                .padding()
            Spacer()
        }
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.all)
    }
}
