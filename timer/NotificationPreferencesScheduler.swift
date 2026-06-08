#if os(iOS)
import Foundation
import UserNotifications

@MainActor
enum NotificationPreferencesScheduler {
    private static let prefix = "timer.pref."

    static func sync(preferences: NotificationPreferencesStore, alarms: [Alarm]) async {
        let status = await AlarmNotificationManager.shared.authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        await cancelPreferenceNotifications()

        if preferences.eveningNudgeEnabled {
            await scheduleEveningNudge(preferences: preferences, alarms: alarms)
        }
        if preferences.planRemindersEnabled {
            await schedulePlaceholder(id: "plan", title: "Plan reminder", body: "Check your wake plan for tomorrow.")
        }
        if preferences.finishSetupReminderEnabled {
            await schedulePlaceholder(id: "finishSetup", title: "Finish setup", body: "Complete your wake-up setup to get the most from \(AppBrand.name).")
        }
    }

    private static func cancelPreferenceNotifications() async {
        let pending = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func scheduleEveningNudge(preferences: NotificationPreferencesStore, alarms: [Alarm]) async {
        let next = nextEnabledAlarm(alarms)
        let alarmTime = next.map { Alarm.formattedTime(hour: $0.hour, minute: $0.minute) }
        let mission = next?.missionType.title ?? "Mission"

        var components = DateComponents()
        components.hour = preferences.eveningNudgeHour
        components.minute = preferences.eveningNudgeMinute

        let content = UNMutableNotificationContent()
        content.title = "Evening nudge"
        if let alarmTime {
            content.body = "Tomorrow: \(alarmTime) · \(mission). \(preferences.eveningNudgeDescription(missionTitle: mission.lowercased()))"
        } else {
            content.body = preferences.eveningNudgeDescription(missionTitle: mission.lowercased())
        }
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(prefix)eveningNudge",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func schedulePlaceholder(id: String, title: String, body: String) async {
        // Placeholder weekly trigger until product logic defines exact schedules.
        var components = DateComponents()
        components.weekday = 2
        components.hour = 10
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(prefix)\(id)",
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func nextEnabledAlarm(_ alarms: [Alarm]) -> Alarm? {
        alarms
            .filter(\.isEnabled)
            .min { a, b in
                let da = a.nextFireDate() ?? .distantFuture
                let db = b.nextFireDate() ?? .distantFuture
                return da < db
            }
    }
}
#endif
