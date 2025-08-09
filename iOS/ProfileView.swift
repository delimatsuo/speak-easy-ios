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
                
                Section(header: Text("Legal")) {
                    NavigationLink(destination: LegalDocumentView(resourceName: "TERMS_OF_USE", title: "Terms of Use")) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    NavigationLink(destination: LegalDocumentView(resourceName: "PRIVACY_POLICY", title: "Privacy Policy")) {
                        Label("Privacy Policy", systemImage: "lock.doc")
                    }
                }
                
                Section(footer: Text("We do not retain your conversations. Only purchase and session metadata (no content) are stored.")) { EmptyView() }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            // Ensure high-contrast nav bar for this sheet regardless of global transparent nav settings
            .modifier(NavBarBackgroundVisible())
            .navigationBarItems(leading: Button("Close") { dismiss() })
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

// iOS 16-only toolbar background, safely no-op on iOS 15
private struct NavBarBackgroundVisible: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        } else {
            content
        }
    }
}


