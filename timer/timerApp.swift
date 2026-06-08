//
//  timerApp.swift
//  timer
//
//  Created by Amay Ramaling Korade on 12/05/26.
//

import SwiftUI

#if os(iOS)
import UIKit
import AppIntents
#endif

@main
struct timerApp: App {
#if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if os(iOS)
extension timerApp: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenTimerAlarmsIntent(),
            phrases: [
                "Open alarms in \(.applicationName)",
                "My alarms in \(.applicationName)",
            ],
            shortTitle: "Open Alarms",
            systemImageName: "alarm"
        )
    }
}
#endif
