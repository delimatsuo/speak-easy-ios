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
                                    Text(product.displayName)
                                        .font(.headline)
                                    Text(product.description)
                                        .font(.caption)
                                        .foregroundColor(.speakEasyTextSecondary)
                                }
                                Spacer()
                                Button(action: { Task { await vm.purchase(product: product) } }) {
                                    Text(product.displayPrice)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(vm.isPurchasing || isOverCap(product: product))
                            }
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
                    Button("Sync") { Task { await CreditsManager.shared.syncWithCloud() } }
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

    private func isOverCap(product: Product) -> Bool {
        if let mapping = CreditProduct.allCases.first(where: { $0.rawValue == product.id }) {
            let current = CreditsManager.shared.remainingSeconds
            return current >= 1800 || current + mapping.grantSeconds > 1800
        }
        return false
    }
}


