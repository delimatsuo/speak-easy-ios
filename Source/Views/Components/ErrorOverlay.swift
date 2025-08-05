import SwiftUI

struct ErrorOverlay: View {
    let error: TranslationError
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    @State private var retryCount = 0
    @State private var isRetrying = false
    
    var body: some View {
        VStack(spacing: 20) {
            errorIcon
            
            VStack(spacing: 8) {
                Text(error.errorDescription ?? "Unknown Error")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                if let recoverySuggestion = error.recoverySuggestion {
                    Text(recoverySuggestion)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            HStack(spacing: 16) {
                if case .rateLimited = error {
                    // Show only dismiss for rate limiting
                    Button("OK") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: {
                        handleRetry()
                    }) {
                        HStack {
                            if isRetrying {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(retryButtonText)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRetrying || retryCount >= maxRetries)
                    
                    Button("Cancel") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRetrying)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 32)
    }
    
    private var maxRetries: Int {
        switch error {
        case .noInternet, .apiError:
            return 3
        case .speechRecognitionFailed:
            return 2
        default:
            return 1
        }
    }
    
    private var retryButtonText: String {
        if isRetrying {
            return "Retrying..."
        } else if retryCount > 0 {
            return "Try Again (\(maxRetries - retryCount) left)"
        } else {
            return "Try Again"
        }
    }
    
    private func handleRetry() {
        guard retryCount < maxRetries, !isRetrying else { return }
        
        isRetrying = true
        retryCount += 1
        
        HapticManager.shared.lightImpact()
        
        // Add delay for exponential backoff
        let delay = pow(2.0, Double(retryCount - 1))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onRetry()
            isRetrying = false
        }
    }
    
    @ViewBuilder
    private var errorIcon: some View {
        switch error {
        case .noInternet:
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.red)
        case .speechRecognitionFailed:
            Image(systemName: "mic.slash")
                .font(.system(size: 48))
                .foregroundColor(.red)
        case .rateLimited:
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundColor(.orange)
        case .serviceUnavailable:
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 48))
                .foregroundColor(.red)
        case .apiError:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
        }
    }
}

struct ToastNotification: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool
    
    enum ToastType {
        case success, warning, error, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        if isShowing {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .foregroundColor(type.color)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Dismiss") {
                    withAnimation {
                        isShowing = false
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        ErrorOverlay(
            error: .noInternet,
            onRetry: {},
            onDismiss: {}
        )
        
        ToastNotification(
            message: "Translation copied to clipboard",
            type: .success,
            isShowing: .constant(true)
        )
    }
    .padding()
}