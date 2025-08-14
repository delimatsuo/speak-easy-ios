//
//  PurchaseViewModel.swift
//  Mervyn Talks
//
//  StoreKit 2 purchase flow for consumable credit products.
//

import Foundation
import StoreKit
import Combine
import Firebase
import FirebaseFirestore

@MainActor
final class PurchaseViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?

    private let creditsManager = CreditsManager.shared
    private let db = Firestore.firestore()
    private var updatesTask: Task<Void, Never>?

    init() {
        listenForTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let ids = Set(CreditProduct.allCases.map { $0.rawValue })
            let fetched = try await Product.products(for: ids)
            // Sort by price ascending for UX
            products = fetched.sorted { $0.displayPrice < $1.displayPrice }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase(product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            // Enforce hard cap (1800s)
            let current = CreditsManager.shared.remainingSeconds
            if let mapping = CreditProduct.allCases.first(where: { $0.rawValue == product.id }) {
                if current >= 1800 || current + mapping.grantSeconds > 1800 {
                    lastError = "Balance limit reached (30 minutes). Please use some minutes before buying more."
                    return
                }
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                try await handleVerification(verification)
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handleVerification(_ verification: VerificationResult<StoreKit.Transaction>) async throws {
        switch verification {
        case .verified(let transaction):
            await grantCredits(for: transaction)
            await transaction.finish()
        case .unverified(_, let error):
            lastError = error.localizedDescription
        }
    }

    private func listenForTransactionUpdates() {
        updatesTask = Task.detached { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.processUpdate(update)
            }
        }
    }

    private func processUpdate(_ update: VerificationResult<StoreKit.Transaction>) async {
        do {
            try await handleVerification(update)
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
        }
    }

    private func grantCredits(for transaction: StoreKit.Transaction) async {
        guard let productID = CreditProduct.allCases.first(where: { $0.rawValue == transaction.productID }) else { return }
        creditsManager.purchaseCompletedGrant(seconds: productID.grantSeconds)
        await recordPurchase(transaction: transaction, seconds: productID.grantSeconds)
    }

    private func recordPurchase(transaction: StoreKit.Transaction, seconds: Int) async {
        do {
            let userId = Auth.auth().currentUser?.uid ?? "unknown"
            let tId = transaction.id.hashValue // hashed transaction identifier proxy
            let expireAt = Timestamp(date: Date(timeIntervalSinceNow: 60*60*24*365))
            let data: [String: Any] = [
                "productId": transaction.productID,
                "secondsGranted": seconds,
                "purchasedAt": Timestamp(date: transaction.purchaseDate),
                "expireAt": expireAt
            ]
            try await db.collection("purchases").document(userId).collection("items").document(String(tId)).setData(data, merge: true)
        } catch {
            // Ignore telemetry errors
        }
    }
}


