//
//  AppDelegate.swift
//  UniversalTranslator
//
//  Universal Translator App - Real-time language translation
//

import UIKit
import Firebase
import FirebaseFirestore
import AVFoundation
import Speech

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
        
        // Initialize API Key Manager (non-blocking). Silence missing-key logs in prod.
        #if DEBUG
        _ = APIKeyManager.shared
        #endif
        
        // Configure appearance
        configureAppearance()
        
        // PERFORMANCE OPTIMIZATION: Preload critical components
        preloadCriticalSystems()
        
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
        // Make navigation bar transparent so our hero gradient shows full-bleed
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = .white
        
        // Configure tab bar if needed
        UITabBar.appearance().tintColor = UIColor.label
    }
    
    // MARK: - Performance Optimization
    
    private func preloadCriticalSystems() {
        print("🚀 Starting critical system preload...")
        
        // Dispatch to background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async {
            // 1. Preload Audio Session
            self.preloadAudioSession()
            
            // 2. Preload Speech Recognition
            self.preloadSpeechRecognition()
            
            // 3. Initialize Core Managers (singleton pattern ensures thread safety)
            self.preloadCoreManagers()
            
            // 4. Warm up translation API connection
            self.warmupTranslationAPI()
            
            print("✅ Critical system preload completed")
        }
    }
    
    private func preloadAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Configure audio session early but don't activate yet
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            print("🎵 Audio session preconfigured")
        } catch {
            print("⚠️ Audio session preload failed: \(error)")
        }
    }
    
    private func preloadSpeechRecognition() {
        // Request speech recognition permission early (async, won't block)
        SFSpeechRecognizer.requestAuthorization { status in
            print("🎤 Speech recognition preload status: \(status.rawValue)")
        }
        
        // Initialize speech recognizer for default locale to warm up the engine
        _ = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        print("🧠 Speech recognizer engine warmed up")
    }
    
    private func preloadCoreManagers() {
        // Initialize singleton managers to warm up their internal state
        _ = AnonymousCreditsManager.shared  // Load user credits
        print("💳 Credits manager preloaded")
        
        // Initialize APIKeyManager (already done in DEBUG, do for RELEASE too)
        #if !DEBUG
        _ = APIKeyManager.shared
        #endif
        print("🔑 API manager preloaded")
    }
    
    private func warmupTranslationAPI() {
        // Create a minimal network request to warm up URLSession and DNS resolution
        guard let url = URL(string: "https://generativelanguage.googleapis.com") else { return }
        
        let task = URLSession.shared.dataTask(with: url) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 Translation API warmup: \(httpResponse.statusCode)")
            }
        }
        task.resume()
        
        // Don't wait for completion - this is just warming up the connection
    }
}