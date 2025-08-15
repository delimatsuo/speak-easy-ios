import SwiftUI

struct ZeroBalanceToast: View {
    let onBuy: () -> Void
    @ObservedObject private var anonymousCredits = AnonymousCreditsManager.shared
    
    private var nextResetDate: String {
        if let resetDate = anonymousCredits.nextResetDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: resetDate)
        }
        return "next Monday"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("No minutes remaining")
                        .font(.subheadline.weight(.semibold))
                    Text("Choose an option below")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            // Two options
            VStack(spacing: 8) {
                // Buy minutes option
                Button {
                    onBuy()
                } label: {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("Buy Minutes")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                
                // Monday reset option
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    
                    Text("Or get 1 free minute on \(nextResetDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

#Preview {
    ZeroBalanceToast {
        print("Buy tapped")
    }
    .background(Color.gray.opacity(0.3))
}
