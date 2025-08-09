//
//  ProfileView.swift
//  Mervyn Talks
//
//  Simple profile sheet showing current account and logout.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var signOutError: String?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Account")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.speakEasyPrimary)
                        VStack(alignment: .leading) {
                            Text(displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            if let email = Auth.auth().currentUser?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        signOut()
                    } label: {
                        Text("Sign out")
                    }
                }
                
                if let err = signOutError {
                    Section {
                        Text(err).foregroundColor(.red).font(.footnote)
                    }
                }
                
                Section(footer: Text("We do not retain your conversations. Only purchase and session metadata (no content) are stored.")) { EmptyView() }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            // Ensure high-contrast nav bar for this sheet regardless of global transparent nav settings
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarColorScheme(.automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Close") { dismiss() } }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
    
    private var displayName: String {
        let user = Auth.auth().currentUser
        return user?.displayName ?? user?.email ?? "Signed in"
    }
    
    private func signOut() {
        do {
            try Auth.auth().signOut()
            dismiss()
        } catch {
            signOutError = error.localizedDescription
        }
    }
}


