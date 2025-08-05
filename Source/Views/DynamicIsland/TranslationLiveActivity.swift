import WidgetKit
import SwiftUI
import ActivityKit

@available(iOS 16.1, *)
struct TranslationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var sourceLanguage: String
        var targetLanguage: String
        var translationState: TranslationLiveState
        var originalText: String
        var translatedText: String
        var confidence: Double?
        var startTime: Date
    }
    
    var sessionId: String
}

enum TranslationLiveState: String, Codable, CaseIterable {
    case recording = "recording"
    case processing = "processing"
    case translating = "translating"
    case playing = "playing"
    case completed = "completed"
    case error = "error"
    
    var displayText: String {
        switch self {
        case .recording:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .translating:
            return "Translating..."
        case .playing:
            return "Playing"
        case .completed:
            return "Complete"
        case .error:
            return "Error"
        }
    }
    
    var color: Color {
        switch self {
        case .recording:
            return .red
        case .processing, .translating:
            return .blue
        case .playing:
            return .green
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .recording:
            return "mic.fill"
        case .processing, .translating:
            return "arrow.triangle.2.circlepath"
        case .playing:
            return "speaker.wave.2.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

@available(iOS 16.1, *)
struct TranslationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TranslationAttributes.self) { context in
            // Lock screen/banner UI
            TranslationLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI (when tapped)
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.state.translationState.icon)
                            .foregroundColor(context.state.translationState.color)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.sourceLanguage)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("→ \(context.state.targetLanguage)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    HStack {
                        if let confidence = context.state.confidence {
                            ConfidenceIndicator(confidence: confidence)
                        }
                        
                        Text(relativeTime(from: context.state.startTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        if !context.state.originalText.isEmpty {
                            Text(context.state.originalText)
                                .font(.caption)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        
                        if !context.state.translatedText.isEmpty {
                            Text(context.state.translatedText)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        
                        Text(context.state.translationState.displayText)
                            .font(.caption)
                            .foregroundColor(context.state.translationState.color)
                        
                        Spacer()
                    }
                }
                
            } compactLeading: {
                // Compact leading (minimal state)
                Image(systemName: context.state.translationState.icon)
                    .foregroundColor(context.state.translationState.color)
                    .font(.caption)
                
            } compactTrailing: {
                // Compact trailing (progress or status)
                switch context.state.translationState {
                case .recording, .processing, .translating:
                    ActivityIndicator()
                case .completed:
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.caption2)
                case .error:
                    Image(systemName: "exclamationmark")
                        .foregroundColor(.red)
                        .font(.caption2)
                default:
                    Text(context.state.targetLanguage.prefix(2).uppercased())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
            } minimal: {
                // Minimal state (just the icon)
                Image(systemName: context.state.translationState.icon)
                    .foregroundColor(context.state.translationState.color)
                    .font(.caption2)
            }
        }
    }
    
    private func relativeTime(from startTime: Date) -> String {
        let interval = Date().timeIntervalSince(startTime)
        
        if interval < 60 {
            return "\(Int(interval))s"
        } else {
            return "\(Int(interval / 60))m"
        }
    }
}

// MARK: - Supporting Views

@available(iOS 16.1, *)
struct TranslationLockScreenView: View {
    let context: ActivityViewContext<TranslationAttributes>
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "translate")
                    .foregroundColor(.accentColor)
                
                Text("Universal Translator")
                    .font(.headline)
                
                Spacer()
                
                Text(context.state.translationState.displayText)
                    .font(.caption)
                    .foregroundColor(context.state.translationState.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(context.state.translationState.color.opacity(0.1))
                    )
            }
            
            if !context.state.originalText.isEmpty || !context.state.translatedText.isEmpty {
                VStack(spacing: 8) {
                    if !context.state.originalText.isEmpty {
                        HStack {
                            Text(context.state.sourceLanguage)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        
                        Text(context.state.originalText)
                            .font(.body)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if !context.state.translatedText.isEmpty {
                        Divider()
                        
                        HStack {
                            Text(context.state.targetLanguage)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let confidence = context.state.confidence {
                                ConfidenceIndicator(confidence: confidence)
                            }
                        }
                        
                        Text(context.state.translatedText)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
    }
}

struct ActivityIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color.accentColor, lineWidth: 2)
            .frame(width: 12, height: 12)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 1)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Live Activity Manager

@available(iOS 16.1, *)
class TranslationLiveActivityManager: ObservableObject {
    static let shared = TranslationLiveActivityManager()
    
    @Published var currentActivity: Activity<TranslationAttributes>?
    
    private init() {}
    
    func startActivity(sourceLanguage: Language, targetLanguage: Language) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }
        
        let attributes = TranslationAttributes(sessionId: UUID().uuidString)
        
        let initialState = TranslationAttributes.ContentState(
            sourceLanguage: sourceLanguage.name,
            targetLanguage: targetLanguage.name,
            translationState: .recording,
            originalText: "",
            translatedText: "",
            confidence: nil,
            startTime: Date()
        )
        
        do {
            currentActivity = try Activity<TranslationAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func updateActivity(
        state: TranslationLiveState,
        originalText: String = "",
        translatedText: String = "",
        confidence: Double? = nil
    ) {
        guard let activity = currentActivity else { return }
        
        Task {
            let updatedState = TranslationAttributes.ContentState(
                sourceLanguage: activity.content.state.sourceLanguage,
                targetLanguage: activity.content.state.targetLanguage,
                translationState: state,
                originalText: originalText.isEmpty ? activity.content.state.originalText : originalText,
                translatedText: translatedText.isEmpty ? activity.content.state.translatedText : translatedText,
                confidence: confidence ?? activity.content.state.confidence,
                startTime: activity.content.state.startTime
            )
            
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }
    
    func endActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            await MainActor.run {
                currentActivity = nil
            }
        }
    }
}