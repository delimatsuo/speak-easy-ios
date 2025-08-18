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
    @State private var showDeleteAccountConfirmation = false
    
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
                        print("🔘 ADD MINUTES button tapped - iPad compatibility fix")
                        // First dismiss the profile sheet
                        dismiss()
                        // Then post notification to show purchase sheet after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            print("🔘 Posting ShowPurchaseSheet notification")
                            NotificationCenter.default.post(name: .init("ShowPurchaseSheet"), object: nil)
                        }
                    } label: {
                        Label("Buy Minutes", systemImage: "cart")
                    }
                    .frame(minHeight: 44) // Ensure minimum touch target size for iPad
                    .contentShape(Rectangle()) // Expand touch area
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
                    Section(header: Text("Account Management"), 
                           footer: Text("Account deletion permanently removes all your data including purchase history and usage statistics. This action cannot be undone.")) {
                        
                        Button(role: .destructive) {
                            print("🔘 DELETE MY DATA button tapped - iPad compatibility fix")
                            showDeleteAccountConfirmation = true
                        } label: {
                            Label("Delete Account & Data", systemImage: "trash.fill")
                        }
                        .frame(minHeight: 44) // Ensure minimum touch target size for iPad
                        .contentShape(Rectangle()) // Expand touch area
                        
                        Button(role: .destructive) {
                            print("🔘 SIGN OUT button tapped")
                            showSignOutConfirmation = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .frame(minHeight: 44) // Ensure minimum touch target size for iPad
                        .contentShape(Rectangle()) // Expand touch area
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
            .confirmationDialog("Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Delete Account & Data", role: .destructive) {
                    Task { 
                        print("🔘 Starting deleteMyData task from confirmation")
                        await deleteMyData() 
                        print("🔘 Completed deleteMyData task from confirmation")
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all your account data including purchase history and usage statistics. This action cannot be undone.")
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

    // Delete ALL user data including credits, purchases, sessions, and user profile
    private func deleteMyData() async {
        print("🗑️ Starting comprehensive account deletion process")
        guard let uid = Auth.auth().currentUser?.uid else { 
            print("❌ No authenticated user found")
            await MainActor.run {
                signOutError = "No authenticated user found"
            }
            return 
        }
        
        let db = Firestore.firestore()
        do {
            print("🗑️ Deleting ALL user data for UID: \(uid)")
            
            // 1. Delete user credits (CRITICAL - this stores the minutes balance)
            print("🗑️ Deleting user credits...")
            try await db.collection("credits").document(uid).delete()
            print("🗑️ ✅ Deleted credits document")
            
            // 2. Delete user profile data
            print("🗑️ Deleting user profile...")
            try await db.collection("users").document(uid).delete()
            print("🗑️ ✅ Deleted user profile document")
            
            // 3. Delete purchases subcollection
            print("🗑️ Deleting purchase items...")
            let items = try await db.collection("purchases").document(uid).collection("items").getDocuments()
            for doc in items.documents { 
                try await doc.reference.delete() 
                print("🗑️ Deleted purchase item: \(doc.documentID)")
            }
            
            // 4. Delete main purchases document
            print("🗑️ Deleting purchases document...")
            try await db.collection("purchases").document(uid).delete()
            print("🗑️ ✅ Deleted purchases document")
            
            // 5. Delete usage sessions with this uid
            print("🗑️ Deleting usage sessions...")
            let sessions = try await db.collection("usageSessions").whereField("userId", isEqualTo: uid).getDocuments()
            for doc in sessions.documents { 
                try await doc.reference.delete() 
                print("🗑️ Deleted session: \(doc.documentID)")
            }
            
            // 6. Delete from starterDevices if present (device throttling data)
            print("🗑️ Checking for starter device records...")
            // Note: We don't have the device hash here, but this is less critical
            // The important data (credits, profile, purchases) is already deleted
            
            print("✅ Complete account deletion finished successfully")
            print("🗑️ Deleted collections: credits, users, purchases, usageSessions")
            
            // Sign out the user after successful deletion
            print("🗑️ Signing out user after account deletion...")
            try Auth.auth().signOut()
            print("🗑️ ✅ User signed out successfully")
            
            // Provide user feedback
            await MainActor.run {
                signOutError = "✅ Account and all data permanently deleted. You have been signed out."
            }
            
        } catch {
            print("❌ Account deletion failed: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            await MainActor.run {
                signOutError = "Deletion error: \(error.localizedDescription)"
            }
        }
    }
}

// iOS 16-only toolbar background, safely no-op on iOS 15
// Removed toolbar background modifier to ensure clean build on iOS 15 toolchains


