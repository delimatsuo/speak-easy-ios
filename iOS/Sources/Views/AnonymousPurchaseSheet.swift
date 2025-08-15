//
//  AnonymousPurchaseSheet.swift
//  Mervyn Talks
//
//  Purchase sheet for anonymous users with clear device vs cloud choice
//

import SwiftUI
import StoreKit
import AuthenticationServices

struct AnonymousPurchaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = PurchaseViewModel()
    @ObservedObject private var anonymousCredits = AnonymousCreditsManager.shared
    @ObservedObject private var auth = AuthViewModel.shared
    @State private var showAppleSignIn = false
    @State private var showTerms = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Add Translation Minutes")
                            .font(.title2.weight(.bold))
                        
                        Text("Choose how to store your credits")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Purchase Options
                    VStack(spacing: 16) {
                        if storeManager.isLoading {
                            ProgressView("Loading products...")
                                .frame(height: 100)
                        } else {
                            ForEach(storeManager.products, id: \.id) { product in
                                PurchaseOptionCard(
                                    product: product,
                                    isLoading: storeManager.isPurchasing,
                                    action: { 
                                        Task { 
                                            await storeManager.purchase(product: product)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    // Storage Choice Warning
                    StorageChoiceCard(
                        onSignInTapped: { showAppleSignIn = true }
                    )
                    
                    // Legal Footer
                    VStack(spacing: 8) {
                        Text("Purchases processed by Apple. Credits are consumable and non-refundable.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("View Terms of Use") {
                            showTerms = true
                        }
                        .font(.caption.weight(.medium))
                        .foregroundColor(.blue)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Buy Minutes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                Task { await storeManager.loadProducts() }
            }
            .sheet(isPresented: $showAppleSignIn) {
                AppleSignInSheet(
                    onSignInComplete: {
                        // After sign-in, user should be taken to the regular purchase sheet
                        // The AnonymousPurchaseSheet should close and regular PurchaseSheet should open
                        dismiss() // Close anonymous purchase sheet
                        
                        // Post notification to show regular purchase sheet after migration
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(name: .init("ShowPurchaseSheet"), object: nil)
                        }
                    }
                )
            }
            .sheet(isPresented: $showTerms) {
                NavigationView {
                    LegalDocumentView(resourceName: "TERMS_OF_USE", title: "Terms of Use")
                }
            }
            .alert(
                "Purchase Error",
                isPresented: Binding(
                    get: { storeManager.lastError != nil },
                    set: { newValue in if !newValue { storeManager.lastError = nil } }
                )
            ) {
                Button("OK") { storeManager.lastError = nil }
            } message: {
                Text(storeManager.lastError ?? "")
            }
        }
    }
    
    private func migrateCreditsToAccount() {
        // This will be handled by the main app when user signs in
        // Credits will be migrated from anonymous to authenticated storage
    }
}

struct PurchaseOptionCard: View {
    let product: Product
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatMinutes(for: product))
                    .font(.headline)
                
                Text("Translation minutes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: action) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text(product.displayPrice)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatMinutes(for product: Product) -> String {
        if let mapping = CreditProduct.allCases.first(where: { $0.rawValue == product.id }) {
            let minutes = mapping.grantSeconds / 60
            return "\(minutes) minutes"
        }
        return product.displayName
    }
}

struct StorageChoiceCard: View {
    let onSignInTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Choose how to store your credits")
                    .font(.headline)
                Spacer()
            }
            
            // Device Only Option
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "iphone")
                        .foregroundColor(.blue)
                    Text("Device Only (Current)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                
                Text("Credits stored on this device only. If you lose, sell, or replace this device, credits will be lost.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Apple Account Option
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "icloud")
                        .foregroundColor(.blue)
                    Text("Sign In with Apple (Recommended)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.blue)
                    Spacer()
                }
                
                Text("Credits saved to your Apple account. Keep your credits even if you lose, sell, or replace your device. Sync across all your devices.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Button("Sign In with Apple to Sync Credits") {
                    onSignInTapped()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct AppleSignInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthViewModel.shared
    let onSignInComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Sync Your Credits")
                        .font(.title2.weight(.bold))
                    
                    Text("Sign in with Apple to save your credits to the cloud and sync across all your devices.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            auth.configureAppleSignInRequest(request)
                        },
                        onCompletion: { result in
                            auth.handleAppleSignInResult(result)
                            
                            // Wait a moment for auth state to update, then handle success
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if auth.isSignedIn {
                                    // Dismiss the sign-in sheet and trigger completion
                                    dismiss()
                                    onSignInComplete()
                                }
                            }
                        }
                    )
                    .frame(height: 50)
                    
                    Button("Continue without signing in") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Sync Credits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AnonymousPurchaseSheet()
}
