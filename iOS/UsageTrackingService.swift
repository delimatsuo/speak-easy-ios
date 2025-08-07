//
//  UsageTrackingService.swift
//  VoiceBridge
//
//  Tracks translation usage time for the minutes-based payment model
//

import Foundation
import Firebase
import FirebaseFirestore

class UsageTrackingService: ObservableObject {
    static let shared = UsageTrackingService()
    
    private let db = Firestore.firestore()
    
    // For beta users: unlimited minutes, but we'll track usage
    @Published var isUnlimitedBeta = true
    
    // Minutes tracking
    @Published var totalMinutesUsed: Double = 0
    @Published var minutesRemainingForDisplay: Double = 30 // Default package size
    @Published var currentSessionStartTime: Date?
    @Published var isSessionActive = false
    @Published var lowMinutesWarningThreshold = 5.0 // Show warning when 5 minutes remain
    
    // Session statistics
    @Published var sessionsToday = 0
    @Published var sessionsThisWeek = 0
    @Published var averageSessionLength: Double = 0
    
    // Timer for active session tracking
    private var sessionTimer: Timer?
    private var sessionLengths: [TimeInterval] = []
    
    private init() {
        Task {
            await loadUserUsageData()
        }
    }
    
    // MARK: - Session Management
    
    func startTranslationSession() {
        guard !isSessionActive else { return }
        
        currentSessionStartTime = Date()
        isSessionActive = true
        
        // Start a timer to update elapsed time display every second
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
        
        print("📊 [UsageTracking] Session started at: \(currentSessionStartTime?.formatted() ?? "unknown")")
    }
    
    func endTranslationSession() {
        guard isSessionActive, let startTime = currentSessionStartTime else { return }
        
        // Stop the timer
        sessionTimer?.invalidate()
        sessionTimer = nil
        
        // Calculate session duration
        let sessionDuration = Date().timeIntervalSince(startTime)
        let minutesUsed = sessionDuration / 60.0
        
        // For analytics, track the session length
        sessionLengths.append(sessionDuration)
        if sessionLengths.count > 100 {
            sessionLengths.removeFirst() // Keep the array from growing too large
        }
        
        // Update tracking stats
        totalMinutesUsed += minutesUsed
        sessionsToday += 1
        sessionsThisWeek += 1
        updateAverageSessionLength()
        
        // For future paid model, we'd subtract from remaining minutes
        if !isUnlimitedBeta {
            minutesRemainingForDisplay -= minutesUsed
            if minutesRemainingForDisplay < 0 {
                minutesRemainingForDisplay = 0
            }
        }
        
        // Reset session state
        isSessionActive = false
        currentSessionStartTime = nil
        
        // Save usage data to Firebase
        Task {
            await saveSessionToFirebase(minutes: minutesUsed, startTime: startTime, endTime: Date())
        }
        
        print("📊 [UsageTracking] Session ended. Duration: \(formatTime(seconds: sessionDuration)), Total used: \(String(format: "%.2f", totalMinutesUsed)) minutes")
    }
    
    func cancelTranslationSession() {
        // Cancel without recording usage
        sessionTimer?.invalidate()
        sessionTimer = nil
        isSessionActive = false
        currentSessionStartTime = nil
        print("📊 [UsageTracking] Session cancelled")
    }
    
    // MARK: - Time Calculations & Formatting
    
    private func updateElapsedTime() {
        guard let startTime = currentSessionStartTime, isSessionActive else { return }
        
        let elapsedSeconds = Date().timeIntervalSince(startTime)
        
        // For debugging during development
        if elapsedSeconds > 0 && Int(elapsedSeconds) % 30 == 0 {
            // Log every 30 seconds for development purposes
            print("📊 [UsageTracking] Session in progress: \(formatTime(seconds: elapsedSeconds))")
        }
    }
    
    func formatTime(seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let remainingSeconds = Int(seconds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func updateAverageSessionLength() {
        guard !sessionLengths.isEmpty else { return }
        
        let totalSeconds = sessionLengths.reduce(0, +)
        averageSessionLength = totalSeconds / Double(sessionLengths.count) / 60.0 // in minutes
    }
    
    // MARK: - Firebase Integration
    
    func saveSessionToFirebase(minutes: Double, startTime: Date, endTime: Date) async {
        do {
            // Get user ID or device identifier
            let userId = Auth.auth().currentUser?.uid ?? UIDevice.current.identifierForVendor?.uuidString ?? "unknown-device"
            
            // Create the session record
            let sessionData: [String: Any] = [
                "userId": userId,
                "startTime": Timestamp(date: startTime),
                "endTime": Timestamp(date: endTime),
                "minutesUsed": minutes,
                "secondsUsed": minutes * 60,
                "isBetaUser": isUnlimitedBeta,
                "device": UIDevice.current.model,
                "osVersion": UIDevice.current.systemVersion,
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
            ]
            
            // Save to the "usageSessions" collection
            _ = try await db.collection("usageSessions").addDocument(data: sessionData)
            
            // Update the aggregated user stats
            let userRef = db.collection("users").document(userId)
            
            try await userRef.setData([
                "totalMinutesUsed": FieldValue.increment(Double(minutes)),
                "sessionsCount": FieldValue.increment(Int64(1)),
                "lastSessionTime": Timestamp(date: endTime),
                "isBetaUser": isUnlimitedBeta,
                "minutesRemaining": isUnlimitedBeta ? 9999 : minutesRemainingForDisplay
            ], merge: true)
            
            print("📊 [UsageTracking] Session data saved to Firebase")
        } catch {
            print("📊 [UsageTracking] Error saving session data: \(error.localizedDescription)")
        }
    }
    
    func loadUserUsageData() async {
        do {
            // Get user ID or device identifier
            guard let userId = Auth.auth().currentUser?.uid ?? UIDevice.current.identifierForVendor?.uuidString else {
                return
            }
            
            // Get user document
            let userDoc = try await db.collection("users").document(userId).getDocument()
            
            if let userData = userDoc.data() {
                // Get usage data
                let totalUsed = userData["totalMinutesUsed"] as? Double ?? 0.0
                let isBeta = userData["isBetaUser"] as? Bool ?? true
                let remaining = userData["minutesRemaining"] as? Double ?? 30.0
                
                // Update UI on main thread
                await MainActor.run {
                    self.totalMinutesUsed = totalUsed
                    self.isUnlimitedBeta = isBeta
                    if !isBeta {
                        self.minutesRemainingForDisplay = remaining
                    }
                }
                
                // Load session statistics
                await loadSessionStatistics(userId: userId)
            }
        } catch {
            print("📊 [UsageTracking] Error loading user data: \(error.localizedDescription)")
        }
    }
    
    private func loadSessionStatistics(userId: String) async {
        do {
            // Get current date info
            let calendar = Calendar.current
            let now = Date()
            let startOfToday = calendar.startOfDay(for: now)
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            
            // Query for today's sessions
            let todayQuery = db.collection("usageSessions")
                .whereField("userId", isEqualTo: userId)
                .whereField("startTime", isGreaterThan: Timestamp(date: startOfToday))
                .order(by: "startTime")
            
            let todaySnapshot = try await todayQuery.getDocuments()
            let todaySessions = todaySnapshot.documents.count
            
            // Query for this week's sessions
            let weekQuery = db.collection("usageSessions")
                .whereField("userId", isEqualTo: userId)
                .whereField("startTime", isGreaterThan: Timestamp(date: startOfWeek))
                .order(by: "startTime")
            
            let weekSnapshot = try await weekQuery.getDocuments()
            let weekSessions = weekSnapshot.documents.count
            
            // Calculate average session length
            var totalSessionLength: Double = 0
            for doc in weekSnapshot.documents {
                if let minutes = doc.data()["minutesUsed"] as? Double {
                    totalSessionLength += minutes
                    self.sessionLengths.append(minutes * 60) // Store in seconds for consistency
                }
            }
            
            let avgSessionLength = weekSessions > 0 ? totalSessionLength / Double(weekSessions) : 0
            
            // Update the UI on main thread
            await MainActor.run {
                self.sessionsToday = todaySessions
                self.sessionsThisWeek = weekSessions
                self.averageSessionLength = avgSessionLength
            }
            
        } catch {
            print("📊 [UsageTracking] Error loading session statistics: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Usage Forecasting (for future paid model)
    
    func estimatedRemainingSessionsAtCurrentRate() -> Int {
        guard averageSessionLength > 0 else { return 0 }
        return Int(minutesRemainingForDisplay / averageSessionLength)
    }
    
    func shouldShowLowMinutesWarning() -> Bool {
        return !isUnlimitedBeta && minutesRemainingForDisplay <= lowMinutesWarningThreshold
    }
    
    func minutesUsedPercentage() -> Double {
        // For display in UI progress bars
        if isUnlimitedBeta { return 0 } // Don't show usage percentage for beta
        
        let totalPackageSize = 30.0 // Default package size
        let used = totalPackageSize - minutesRemainingForDisplay
        return min(1.0, max(0.0, used / totalPackageSize))
    }
}

// MARK: - Usage Data Models

struct TranslationSession: Codable {
    let userId: String
    let startTime: Date
    let endTime: Date
    let minutesUsed: Double
    let secondsUsed: Double
    let isBetaUser: Bool
}

struct UserUsageData: Codable {
    let userId: String
    var totalMinutesUsed: Double
    var sessionsCount: Int
    var lastSessionTime: Date?
    var minutesRemaining: Double
    var isBetaUser: Bool
}

// MARK: - Notification Names

extension Notification.Name {
    static let sessionStarted = Notification.Name("translationSessionStarted")
    static let sessionEnded = Notification.Name("translationSessionEnded")
    static let lowMinutesWarning = Notification.Name("lowMinutesWarning")
}
