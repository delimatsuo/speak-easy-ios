//
//  AppDelegate.swift
//  UniversalTranslator
//
//  Universal Translator App - Real-time language translation
//

import UIKit
import Firebase
import FirebaseFirestore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Configure Firestore settings for offline support
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings
        
        // Log successful initialization
        print("✅ Firebase initialized successfully")
        print("📱 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🔥 Project ID: \(FirebaseApp.app()?.options.projectID ?? "unknown")")
        
        // Configure appearance
        configureAppearance()
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
    
    // MARK: - Private Methods
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBlue
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Configure tab bar if needed
        UITabBar.appearance().tintColor = UIColor.systemBlue
    }
}