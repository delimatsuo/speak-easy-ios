import SwiftUI
import Firebase

@main
struct UniversalTranslatorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    AppConfig.logConfiguration()
                }
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