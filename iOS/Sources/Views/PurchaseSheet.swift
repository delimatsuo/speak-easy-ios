//
//  PurchaseSheet.swift
//  Mervyn Talks
//
//  Presents consumable credit options via StoreKit 2.
//

import SwiftUI
import StoreKit

struct PurchaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = PurchaseViewModel()
    @State private var showTerms = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Add minutes")) {
                    if vm.isLoading {
                        ProgressView()
                    } else {
                        ForEach(vm.products, id: \.id) { product in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatMinutes(for: product))
                                        .font(.headline)
                                    Text("Translation minutes")
                                        .font(.caption)
                                        .foregroundColor(.speakEasyTextSecondary)
                                }
                                Spacer()
                                Button(action: { 
                                    print("🔘 Purchase button tapped for \(product.displayName) - iPad compatibility fix")
                                    Task { 
                                        print("🔘 Starting purchase task for \(product.id)")
                                        await vm.purchase(product: product)
                                        print("🔘 Completed purchase task for \(product.id)")
                                    }
                                }) {
                                    Text(product.displayPrice)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(minWidth: 60, minHeight: 32) // Ensure minimum touch target
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(vm.isPurchasing || isOverCap(product: product))
                                .contentShape(Rectangle()) // Expand touch area
                                .onAppear {
                                    let isPurchasingDisabled = vm.isPurchasing
                                    let isOverCapDisabled = isOverCap(product: product)
                                    let currentSeconds = CreditsManager.shared.remainingSeconds
                                    print("🔍 Purchase button state for \(product.id):")
                                    print("  - isPurchasing: \(isPurchasingDisabled)")
                                    print("  - isOverCap: \(isOverCapDisabled)")
                                    print("  - currentSeconds: \(currentSeconds)")
                                    print("  - products loaded: \(vm.products.count)")
                                    print("  - isLoading: \(vm.isLoading)")
                                }
                            }
                            .frame(minHeight: 60) // Ensure minimum row height for iPad
                            .contentShape(Rectangle()) // Make entire row tappable
                        }
                    }
                }
                Section(footer:
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Purchases by Apple. Consumable credits are not restorable. Minutes are deducted by the second while recording.")
                                    .font(.caption)
                                    .foregroundColor(.speakEasyTextSecondary)
                                Button(action: { showTerms = true }) {
                                    Text("View Terms of Use")
                                        .font(.caption.weight(.semibold))
                                }
                            }
                ) {
                    EmptyView()
                }
            }
            .navigationTitle("Buy minutes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Sync status indicator
                    if CreditsManager.shared.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .opacity(0.7)
                    }
                }
            }
            .onAppear { Task { await vm.loadProducts() } }
            .sheet(isPresented: $showTerms) {
                NavigationView {
                    LegalDocumentView(resourceName: "TERMS_OF_USE", title: "Terms of Use")
                }
            }
            .alert(
                "Purchase Error",
                isPresented: Binding(
                    get: { vm.lastError != nil },
                    set: { newValue in if !newValue { vm.lastError = nil } }
                )
            ) {
                Button("OK") { vm.lastError = nil }
            } message: { Text(vm.lastError ?? "") }
        }
    }

    private func formatMinutes(for product: Product) -> String {
        if let mapping = CreditProduct.allCases.first(where: { $0.rawValue == product.id }) {
            let minutes = mapping.grantSeconds / 60
            return "\(minutes) minutes"
        }
        return product.displayName
    }

    private func isOverCap(product: Product) -> Bool {
        if let mapping = CreditProduct.allCases.first(where: { $0.rawValue == product.id }) {
            let current = CreditsManager.shared.remainingSeconds
            return current >= 1800 || current + mapping.grantSeconds > 1800
        }
        return false
    }
}


