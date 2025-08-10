//
//  UniversalTranslatorWatchApp.swift
//  UniversalTranslator Watch App
//
//  Main app entry point for the Watch app
//

import SwiftUI

@main
struct UniversalTranslatorWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
                .onAppear {
                    // Activate Watch connectivity on launch
                    connectivityManager.activate()
                }
        }
    }
}