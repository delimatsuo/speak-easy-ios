//
//  ProfileView.swift
//  Mervyn Talks
//
//  Simple profile sheet showing current account and logout.
//

import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseFirestore

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var signOutError: String?
    @State private var showSignOutConfirmation = false
    
    private var isSignedIn: Bool {
        guard let user = Auth.auth().currentUser else { return false }
        return !user.isAnonymous
    }
    
    private var authStatusInfo: (title: String, subtitle: String, systemImage: String, color: Color) {
        if isSignedIn {
            return ("Signed In", displayName, "checkmark.circle.fill", .green)
        } else {
            return ("Anonymous Mode", "Credits saved locally only", "questionmark.circle.fill", .orange)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Account Status Section (New)
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: authStatusInfo.systemImage)
                            .font(.system(size: 24))
                            .foregroundColor(authStatusInfo.color)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authStatusInfo.title)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(authStatusInfo.subtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if isSignedIn, let email = Auth.auth().currentUser?.email {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if isSignedIn {
                            Image(systemName: "icloud.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Error Display
                if let err = signOutError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                // MARK: - Credits & Purchase Section
                Section(header: Text("Credits")) {
                    Button {
                        // First dismiss the profile sheet
                        dismiss()
                        // Then post notification to show purchase sheet after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: .init("ShowPurchaseSheet"), object: nil)
                        }
                    } label: {
                        Label("Buy Minutes", systemImage: "cart")
                    }
                }
                
                // MARK: - Legal Section
                Section(header: Text("Legal")) {
                    NavigationLink(destination: LegalDocumentView(resourceName: "TERMS_OF_USE", title: "Terms of Use")) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    NavigationLink(destination: LegalDocumentView(resourceName: "PRIVACY_POLICY", title: "Privacy Policy")) {
                        Label("Privacy Policy", systemImage: "lock.doc")
                    }
                }
                
                // MARK: - Account Actions Section (Bottom)
                if isSignedIn {
                    Section(header: Text("Account Actions")) {
                        Button(role: .destructive) {
                            Task { await deleteMyData() }
                        } label: {
                            Label("Delete My Data", systemImage: "trash")
                        }
                        
                        Button(role: .destructive) {
                            showSignOutConfirmation = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                
                // MARK: - Privacy Notice
                Section(footer: Text("We do not retain your conversations. Only purchase and session metadata (no content) are stored.")) { 
                    EmptyView() 
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out? Your credits will remain in your account.")
            }
        }
    }
    
    private var displayName: String {
        let user = Auth.auth().currentUser
        return user?.displayName ?? user?.email ?? "Signed in"
    }
    
    private func signOut() {
        signOutError = nil // Clear any previous errors
        
        do {
            try Auth.auth().signOut()
            print("✅ Successfully signed out")
            
            // Dismiss the profile sheet
            DispatchQueue.main.async {
                self.dismiss()
            }
        } catch {
            print("❌ Sign out failed: \(error.localizedDescription)")
            signOutError = error.localizedDescription
        }
    }

    // Delete purchases and session metadata belonging to the current user
    private func deleteMyData() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        do {
            // Delete purchases subcollection
            let items = try await db.collection("purchases").document(uid).collection("items").getDocuments()
            for doc in items.documents { try await doc.reference.delete() }
            // Delete usageSessions with this uid
            let sessions = try await db.collection("usageSessions").whereField("userId", isEqualTo: uid).getDocuments()
            for doc in sessions.documents { try await doc.reference.delete() }
        } catch {
            signOutError = "Deletion error: \(error.localizedDescription)"
        }
    }
}

// iOS 16-only toolbar background, safely no-op on iOS 15
// Removed toolbar background modifier to ensure clean build on iOS 15 toolchains


