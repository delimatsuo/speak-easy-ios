//
//  CreditsManager.swift
//  Mervyn Talks
//
//  Manages per-second translation credits with secure persistence and cloud sync.
//

import Foundation
import Combine
import StoreKit
import Firebase
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class CreditsManager: ObservableObject {
    static let shared = CreditsManager()

    // MARK: - Published State
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var isSyncing: Bool = false
    @Published var lastSyncError: String?

    // MARK: - Storage Keys
    private let keychainServiceKey = "com.mervyntalks.credits.remainingSeconds"
    private let keychainUpdatedAtKey = "com.mervyntalks.credits.updatedAt"

    // MARK: - Firebase
    private let db = Firestore.firestore()
    private var lastCloudSyncAt: Date?
    private let minimumCloudSyncInterval: TimeInterval = 15 // seconds

    // MARK: - Session Deduction Tracking (per recording session)
    private var sessionStartTime: Date?
    private var sessionSecondsDeducted: Int = 0
    private var updatesTask: Task<Void, Never>?

    private init() {
        Task {
            await ensureAnonymousAuth()
            await loadFromStorage()
            await syncWithCloud()
            listenForTransactionUpdates()
        }
    }

    // MARK: - Public API
    func setSessionStarted() {
        sessionStartTime = Date()
        sessionSecondsDeducted = 0
    }

    private func listenForTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { continue }
                switch update {
                case .verified(let transaction):
                    if let mapping = CreditProduct(rawValue: transaction.productID) {
                        await MainActor.run { self.purchaseCompletedGrant(seconds: mapping.grantSeconds) }
                    }
                    await transaction.finish()
                case .unverified:
                    break
                }
            }
        }
    }

    func setSessionStoppedAndRoundUp() {
        guard let start = sessionStartTime else { return }
        let elapsed = Date().timeIntervalSince(start)
        let shouldBeDeducted = Int(ceil(elapsed))
        if shouldBeDeducted > sessionSecondsDeducted {
            let delta = shouldBeDeducted - sessionSecondsDeducted
            deduct(seconds: delta)
        }
        sessionStartTime = nil
        sessionSecondsDeducted = 0
    }

    func add(seconds: Int) {
        guard seconds > 0 else { return }
        remainingSeconds &+= seconds
        Task { await saveToStorageAndCloud() }
    }

    func deduct(seconds: Int) {
        guard seconds > 0 else { return }
        guard remainingSeconds > 0 else { return }
        let toDeduct = min(seconds, remainingSeconds)
        remainingSeconds &-= toDeduct
        sessionSecondsDeducted &+= toDeduct
        Task { await saveToStorageAndCloud() }
    }

    func canStartTranslation() -> Bool {
        return remainingSeconds > 0
    }

    func purchaseCompletedGrant(seconds: Int) {
        // Enforce hard cap at 1800s
        let cappedGrant = max(0, min(seconds, max(0, 1800 - remainingSeconds)))
        add(seconds: cappedGrant)
    }

    /// Convenience purchase API (non-UI). Preferred flow is via `PurchaseViewModel`.
    func purchase(productId: String) async {
        do {
            let products = try await Product.products(for: [productId])
            guard let product = products.first else { return }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    if let mapping = CreditProduct(rawValue: transaction.productID) {
                        purchaseCompletedGrant(seconds: mapping.grantSeconds)
                    }
                    await transaction.finish()
                case .unverified:
                    break
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // Silently fail; UI layer should surface errors
        }
    }

    // MARK: - Persistence
    func loadFromStorage() async {
        // Load from Keychain first
        if let stored = try? KeychainManager.shared.retrieveAPIKey(forService: keychainServiceKey),
           let value = Int(stored) {
            remainingSeconds = max(0, value)
        } else {
            remainingSeconds = 0
        }
    }

    private func saveToStorage() {
        do {
            try KeychainManager.shared.storeAPIKey(String(remainingSeconds), forService: keychainServiceKey)
            try KeychainManager.shared.storeAPIKey(String(Int(Date().timeIntervalSince1970)), forService: keychainUpdatedAtKey)
        } catch {
            // Do not log sensitive details
            print("Failed to save credits to keychain: \(error.localizedDescription)")
        }
    }

    private func saveToStorageAndCloud() async {
        saveToStorage()
        // Throttle cloud writes during active sessions
        let now = Date()
        if let last = lastCloudSyncAt, now.timeIntervalSince(last) < minimumCloudSyncInterval {
            return
        }
        lastCloudSyncAt = now
        await syncWithCloud()
    }

    // MARK: - Cloud Sync (Firestore)
    func syncWithCloud() async {
        isSyncing = true
        defer { isSyncing = false }

        guard let uid = Auth.auth().currentUser?.uid else {
            await ensureAnonymousAuth()
            guard let uid2 = Auth.auth().currentUser?.uid else { return }
            await upsertRemote(uid: uid2)
            return
        }

        do {
            // Fetch remote
            let docRef = db.collection("credits").document(uid)
            let snapshot = try await docRef.getDocument()
            let remoteSeconds = (snapshot.data()? ["seconds"] as? Int) ?? 0

            // Merge: take max for basic fraud resistance
            let merged = max(remoteSeconds, remainingSeconds)
            if merged != remainingSeconds {
                remainingSeconds = merged
                saveToStorage()
            }

            // Write back server with merged value
            try await docRef.setData([
                "seconds": merged,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func upsertRemote(uid: String) async {
        do {
            try await db.collection("credits").document(uid).setData([
                "seconds": remainingSeconds,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    private func ensureAnonymousAuth() async {
        if Auth.auth().currentUser == nil {
            do {
                _ = try await Auth.auth().signInAnonymously()
            } catch {
                lastSyncError = error.localizedDescription
            }
        }
    }
}

// MARK: - Constants for Credit Products
enum CreditProduct: String, CaseIterable {
    case seconds300 = "com.mervyntalks.credits.300s" // 5 minutes
    case seconds600 = "com.mervyntalks.credits.600s" // 10 minutes

    var grantSeconds: Int {
        switch self {
        case .seconds300: return 300
        case .seconds600: return 600
        }
    }
}

// MARK: - Starter Grant with Device Throttle
extension CreditsManager {
    func grantStarterIfNeededWithDeviceThrottle() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let deviceHash = DeviceIdentity.shared.deviceHash
        let deviceKey = "starterGrantedDevice_\(deviceHash)"
        let deviceGranted = UserDefaults.standard.bool(forKey: deviceKey)
        do {
            // Enforce: Only one starter per device (ever) AND one per UID
            let doc = try await db.collection("credits").document(uid).getDocument()
            let alreadyGrantedByUID = (doc.data()? ["starterGranted"] as? Bool) ?? false

            // Check global device registry to prevent multiple UIDs on the same device
            let deviceDoc = try? await db.collection("starterDevices").document(deviceHash).getDocument()
            let deviceUsed = deviceDoc?.exists ?? false

            if !alreadyGrantedByUID && !deviceGranted && !deviceUsed {
                add(seconds: 300)
                try await db.collection("credits").document(uid).setData([
                    "starterGranted": true,
                    "starterGrantedAt": FieldValue.serverTimestamp(),
                    "starterDeviceHash": deviceHash
                ], merge: true)
                try await db.collection("starterDevices").document(deviceHash).setData([
                    "claimedAt": FieldValue.serverTimestamp(),
                    "uid": uid
                ], merge: false)
                UserDefaults.standard.set(true, forKey: deviceKey)
            }
        } catch {
            // Ignore
        }
    }
}


