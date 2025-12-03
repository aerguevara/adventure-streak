//
//  Adventure_StreakApp.swift
//  Adventure Streak
//
//  Created by Anyelo Reyes on 22/11/25.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    #if canImport(FirebaseCore)
    FirebaseApp.configure()
    #endif
    return true
  }
}

@main
struct Adventure_StreakApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var configService = GameConfigService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(configService)
                .task {
                    await configService.loadConfigIfNeeded()
                }
        }
    }
}
