//
//  LucyApp.swift
//  Lucy
//
//  Created by M. De Vries on 15/12/2024.
//

import SwiftUI

@main
struct LucyApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: LucyAppDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
}

class LucyAppDelegate: NSObject, UIApplicationDelegate, ObservableObject, UNUserNotificationCenterDelegate{
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.banner)
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        center.delegate = self
        return true
    }
}

var center: UNUserNotificationCenter = UNUserNotificationCenter.current()

