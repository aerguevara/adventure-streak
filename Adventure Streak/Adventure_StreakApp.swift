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
import FirebaseMessaging
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif
import BackgroundTasks
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    #if canImport(FirebaseCore)
    FirebaseApp.configure()
    #if DEBUG
    print("[Firebase] App configured (Debug)")
    #endif
    #endif
    
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self
    
    // Check current permissions silently. Only register if already authorized.
    UNUserNotificationCenter.current().getNotificationSettings { settings in
        if settings.authorizationStatus == .authorized {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    // Registrar tareas en background (HealthKit refresh)
    BackgroundTaskService.shared.registerTasks()
    
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("CRASHLYTICS_TEST_CRASH") {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("Triggering test crash via launch argument")
        #endif
        fatalError("Test Crashlytics crash")
    }
    #endif
    return true
  }
  
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      Messaging.messaging().apnsToken = deviceToken
  }
  
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
      print("FCM token: \(fcmToken ?? "nil")")
      guard let token = fcmToken else { return }
      let userId = AuthenticationService.shared.userId
      NotificationService.shared.handleNewFCMToken(token, userId: userId)
  }
  
  // Mostrar notificaciones en foreground
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
      return [.banner, .sound, .badge]
  }

  // Handle Notification Tap (User Interaction)
  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
      let userInfo = response.notification.request.content.userInfo
      
      if let type = userInfo["type"] as? String, type == "mock_import_trigger" {
          print("👆 [Notification] User tapped simulation trigger. Starting fetch...")
          #if DEBUG
          HealthKitManager.shared.simulateBackgroundFetch(delay: 0.5)
          #endif
      }
      
      completionHandler()
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
