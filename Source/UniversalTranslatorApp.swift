import SwiftUI
import Firebase

@main
struct UniversalTranslatorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            RootGateView()
                .onAppear {
                    AppConfig.logConfiguration()
                }
        }
    }
}

private struct RootGateView: View {
    @AppStorage("hasAcceptedPolicies") private var hasAcceptedPolicies = false

    var body: some View {
        if hasAcceptedPolicies {
            ContentView()
        } else {
            FirstRunConsentView()
        }
    }
}

private struct FirstRunConsentView: View {
    @AppStorage("hasAcceptedPolicies") private var hasAcceptedPolicies = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Welcome to Mervyn Talks")
                    .font(.title.bold())
                Text("We keep things private: we don't store conversations; only minimal purchase and session metadata for up to 12 months.")
                HStack(spacing: 16) {
                    NavigationLink("Terms of Use") { LegalDocumentView(resourceName: "TERMS_OF_USE", title: "Terms of Use") }
                    NavigationLink("Privacy Policy") { LegalDocumentView(resourceName: "PRIVACY_POLICY", title: "Privacy Policy") }
                }
                Spacer()
                Button(action: { hasAcceptedPolicies = true }) {
                    Text("Agree and continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Consent")
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize Firebase only if configuration is available
        if AppConfig.Firebase.isConfigured {
            FirebaseApp.configure()
            print("✅ Firebase initialized successfully")
        } else {
            print("⚠️ Firebase configuration not found - app will run without Firebase features")
        }
        
        // Validate app configuration
        let configValidation = AppConfig.validateConfiguration()
        switch configValidation {
        case .valid:
            print("✅ App configuration is valid")
        case .invalid(let issues):
            print("❌ App configuration issues found:")
            for issue in issues {
                print("   • \(issue)")
            }
        }
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Log configuration information for debugging
        if AppConfig.Debug.enableLogging {
            AppConfig.logConfiguration()
        }
    }
}