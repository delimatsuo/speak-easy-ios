import SwiftUI

/// Modern OAuth 2.0 login view with provider selection and enhanced UX
struct OAuth2LoginView: View {
    @StateObject private var authManager = EnhancedAuthenticationManager()
    @State private var selectedProvider: OAuth2Provider?
    @State private var showingError: Bool = false
    @State private var isAuthenticating: Bool = false
    
    let onAuthenticationComplete: (EnhancedAuthenticationManager.AuthenticatedUser) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    providerButtonsSection
                    anonymousOptionSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Group {
                if isAuthenticating {
                    LoadingOverlay()
                }
            }
        )
        .alert("Authentication Error", isPresented: $showingError) {
            Button("Retry", action: retryAuthentication)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(authManager.lastError?.userFriendlyMessage ?? "An error occurred")
        }
        .onChange(of: authManager.currentUser) { user in
            if let user = user {
                onAuthenticationComplete(user)
            }
        }
        .onChange(of: authManager.lastError) { error in
            showingError = error != nil
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Title and Subtitle
            VStack(spacing: 8) {
                Text("Welcome to Universal Translator")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Choose how you'd like to get started")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Provider Buttons Section
    private var providerButtonsSection: some View {
        VStack(spacing: 16) {
            Text("Sign in with")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ForEach(OAuth2Provider.allCases) { provider in
                    ProviderButton(
                        provider: provider,
                        isSelected: selectedProvider == provider,
                        isLoading: isAuthenticating && selectedProvider == provider
                    ) {
                        authenticateWith(provider)
                    }
                }
            }
        }
    }
    
    // MARK: - Anonymous Option Section
    private var anonymousOptionSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack { Divider() }
                Text("OR")
                    .font(.caption)
                    .foregroundColor(.secondary)
                VStack { Divider() }
            }
            
            Button(action: continueAnonymously) {
                HStack {
                    Image(systemName: "person.crop.circle.dashed")
                        .font(.title2)
                    Text("Continue without signing in")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isAuthenticating)
            
            Text("Limited features • No data sync • 20 free translations")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Actions
    private func authenticateWith(_ provider: OAuth2Provider) {
        selectedProvider = provider
        isAuthenticating = true
        
        Task {
            do {
                try await authManager.authenticateWithOAuth(provider)
            } catch {
                // Error handling is done through state binding
                isAuthenticating = false
                selectedProvider = nil
            }
        }
    }
    
    private func continueAnonymously() {
        authManager.continueAnonymously()
    }
    
    private func retryAuthentication() {
        guard let provider = selectedProvider else { return }
        authenticateWith(provider)
    }
}

// MARK: - Provider Button
private struct ProviderButton: View {
    let provider: OAuth2Provider
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                // Provider Icon
                Image(systemName: providerIcon)
                    .font(.title2)
                    .frame(width: 24)
                
                // Provider Name
                Text("Continue with \(provider.displayName)")
                    .fontWeight(.medium)
                
                Spacer()
                
                // Loading Indicator
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .disabled(isLoading)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
    
    private var providerIcon: String {
        switch provider {
        case .google:
            return "globe"
        case .apple:
            return "applelogo"
        case .microsoft:
            return "microsoft.logo"
        case .github:
            return "externaldrive.connected.to.line.below"
        }
    }
    
    private var backgroundColor: Color {
        switch provider {
        case .apple:
            return Color.black
        default:
            return Color(.systemBackground)
        }
    }
    
    private var foregroundColor: Color {
        switch provider {
        case .apple:
            return .white
        default:
            return .primary
        }
    }
    
    private var borderColor: Color {
        switch provider {
        case .apple:
            return Color.black
        default:
            return Color(.systemGray4)
        }
    }
}

// MARK: - Loading Overlay
private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Authenticating...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

// MARK: - Migration Prompt View
struct OAuth2MigrationPromptView: View {
    let currentUser: EnhancedAuthenticationManager.AuthenticatedUser
    let onMigrate: (OAuth2Provider) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Upgrade Your Account")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Sign in to sync your data across devices and unlock premium features")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Benefits
            VStack(alignment: .leading, spacing: 12) {
                BenefitRow(icon: "icloud", text: "Sync across all devices")
                BenefitRow(icon: "infinity", text: "Unlimited translations")
                BenefitRow(icon: "shield", text: "Secure cloud backup")
                BenefitRow(icon: "star", text: "Premium features")
            }
            
            // Provider Buttons
            VStack(spacing: 12) {
                ForEach([OAuth2Provider.google, OAuth2Provider.apple]) { provider in
                    Button(action: { onMigrate(provider) }) {
                        HStack {
                            Image(systemName: provider == .apple ? "applelogo" : "globe")
                            Text("Sign in with \(provider.displayName)")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(provider == .apple ? Color.black : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            
            // Dismiss Option
            Button("Maybe Later", action: onDismiss)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Benefit Row
private struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct OAuth2LoginView_Previews: PreviewProvider {
    static var previews: some View {
        OAuth2LoginView { _ in }
            .preferredColorScheme(.light)
        
        OAuth2LoginView { _ in }
            .preferredColorScheme(.dark)
    }
}