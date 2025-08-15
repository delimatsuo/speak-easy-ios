//
//  AnonymousCreditsManager.swift
//  Mervyn Talks
//
//  Manages anonymous device-based credits with weekly reset system
//  Apple-compliant: No account required, full functionality without sign-in
//

import Foundation
import Combine
import StoreKit

@MainActor
final class AnonymousCreditsManager: ObservableObject {
    static let shared = AnonymousCreditsManager()
    
    // MARK: - Published State
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var weeklyFreeSeconds: Int = 0
    @Published private(set) var nextResetDate: Date?
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?
    
    // MARK: - Storage Keys
    private let remainingSecondsKey = "anonymous.credits.remainingSeconds"
    private let weeklyFreeSecondsKey = "anonymous.credits.weeklyFreeSeconds"
    private let lastResetWeekKey = "anonymous.credits.lastResetWeek"
    private let lastResetYearKey = "anonymous.credits.lastResetYear"
    
    // MARK: - Constants
    private let weeklyFreeLimit = 60 // 1 minute per week
    private var updatesTask: Task<Void, Never>?
    
    private init() {
        loadCredits()
        checkMondayReset()
        grantFirstTimeUserBonus() // Grant 1 minute to new users
        listenForTransactionUpdates()
    }
    
    // MARK: - Weekly Reset Logic
    private func checkMondayReset() {
        let now = Date()
        let calendar = Calendar.current
        
        // Get current week and year
        let currentWeek = calendar.component(.weekOfYear, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        // Get last reset week and year
        let lastResetWeek = UserDefaults.standard.integer(forKey: lastResetWeekKey)
        let lastResetYear = UserDefaults.standard.integer(forKey: lastResetYearKey)
        
        // Check if it's Monday (weekday 2) and we haven't reset this week
        let isMonday = calendar.component(.weekday, from: now) == 2
        let isNewWeek = (currentYear != lastResetYear) || (currentWeek != lastResetWeek)
        
        if isMonday && isNewWeek && remainingSeconds < weeklyFreeLimit {
            // Reset to exactly 1 minute (not additive)
            weeklyFreeSeconds = weeklyFreeLimit
            remainingSeconds = max(remainingSeconds, weeklyFreeLimit)
            
            // Save reset tracking
            UserDefaults.standard.set(currentWeek, forKey: lastResetWeekKey)
            UserDefaults.standard.set(currentYear, forKey: lastResetYearKey)
            
            saveCredits()
            calculateNextResetDate()
            
            print("🔄 Monday reset: Free minute restored (Week \(currentWeek), Year \(currentYear))")
        } else {
            calculateNextResetDate()
        }
    }
    
    private func calculateNextResetDate() {
        let calendar = Calendar.current
        let now = Date()
        
        // Find next Monday
        var nextMonday = now
        while calendar.component(.weekday, from: nextMonday) != 2 {
            nextMonday = calendar.date(byAdding: .day, value: 1, to: nextMonday) ?? now
        }
        
        // If today is Monday and we already reset, find next Monday
        if calendar.component(.weekday, from: now) == 2 {
            let currentWeek = calendar.component(.weekOfYear, from: now)
            let lastResetWeek = UserDefaults.standard.integer(forKey: lastResetWeekKey)
            
            if currentWeek == lastResetWeek {
                nextMonday = calendar.date(byAdding: .day, value: 7, to: nextMonday) ?? now
            }
        }
        
        nextResetDate = nextMonday
    }
    
    // MARK: - Credit Management
    func canStartTranslation() -> Bool {
        checkMondayReset() // Check on each use
        return remainingSeconds > 0
    }
    
    func deduct(seconds: Int) {
        guard seconds > 0 else { return }
        guard remainingSeconds >= seconds else { return }
        
        remainingSeconds -= seconds
        
        // Track if we're using weekly free seconds
        if weeklyFreeSeconds > 0 {
            let freeUsed = min(seconds, weeklyFreeSeconds)
            weeklyFreeSeconds -= freeUsed
        }
        
        saveCredits()
    }
    
    func add(seconds: Int) {
        guard seconds > 0 else { return }
        remainingSeconds += seconds
        saveCredits()
    }
    
    // MARK: - Anonymous Purchases
    func purchaseCredits(productId: String) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let products = try await Product.products(for: [productId])
            guard let product = products.first else {
                lastError = "Product not found"
                return
            }
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    if let mapping = CreditProduct(rawValue: transaction.productID) {
                        add(seconds: mapping.grantSeconds)
                        print("✅ Anonymous purchase successful: \(mapping.grantSeconds) seconds added")
                    }
                    await transaction.finish()
                case .unverified:
                    lastError = "Purchase verification failed"
                }
            case .userCancelled:
                print("Purchase cancelled by user")
            case .pending:
                print("Purchase pending")
            @unknown default:
                lastError = "Unknown purchase result"
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
            print("❌ Purchase failed: \(error)")
        }
    }
    
    // MARK: - StoreKit Transaction Monitoring
    private func listenForTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { continue }
                switch update {
                case .verified(let transaction):
                    if let mapping = CreditProduct(rawValue: transaction.productID) {
                        await MainActor.run {
                            self.add(seconds: mapping.grantSeconds)
                        }
                    }
                    await transaction.finish()
                case .unverified:
                    break
                }
            }
        }
    }
    
    // MARK: - Persistence
    private func loadCredits() {
        remainingSeconds = UserDefaults.standard.integer(forKey: remainingSecondsKey)
        weeklyFreeSeconds = UserDefaults.standard.integer(forKey: weeklyFreeSecondsKey)
    }
    
    private func saveCredits() {
        UserDefaults.standard.set(remainingSeconds, forKey: remainingSecondsKey)
        UserDefaults.standard.set(weeklyFreeSeconds, forKey: weeklyFreeSecondsKey)
    }
    
    // MARK: - Account Migration Support
    func migrateToAccount() -> Int {
        let creditsToMigrate = remainingSeconds
        // Keep credits for now - actual migration happens in CreditsManager
        return creditsToMigrate
    }
    
    func clearAfterMigration() {
        remainingSeconds = 0
        weeklyFreeSeconds = 0
        saveCredits()
    }
    
    // MARK: - First Time User Bonus
    private func grantFirstTimeUserBonus() {
        let hasReceivedBonus = UserDefaults.standard.bool(forKey: "anonymous.credits.firstTimeBonus")
        
        // Grant 1 minute to brand new users
        if !hasReceivedBonus && remainingSeconds == 0 && weeklyFreeSeconds == 0 {
            remainingSeconds = weeklyFreeLimit // Grant 1 minute
            weeklyFreeSeconds = weeklyFreeLimit
            UserDefaults.standard.set(true, forKey: "anonymous.credits.firstTimeBonus")
            saveCredits()
            print("🎁 First-time user bonus: 1 minute granted")
        }
    }
    
    // MARK: - Debug Info
    var debugInfo: String {
        let calendar = Calendar.current
        let now = Date()
        let currentWeek = calendar.component(.weekOfYear, from: now)
        let currentYear = calendar.component(.year, from: now)
        let lastResetWeek = UserDefaults.standard.integer(forKey: lastResetWeekKey)
        let lastResetYear = UserDefaults.standard.integer(forKey: lastResetYearKey)
        
        return """
        Anonymous Credits Debug:
        - Remaining: \(remainingSeconds)s
        - Weekly Free: \(weeklyFreeSeconds)s
        - Current Week: \(currentWeek)/\(currentYear)
        - Last Reset: \(lastResetWeek)/\(lastResetYear)
        - Next Reset: \(nextResetDate?.formatted() ?? "Unknown")
        """
    }
}

// MARK: - Credit Products
// Note: CreditProduct enum is defined in CreditsManager.swift and shared across the app
