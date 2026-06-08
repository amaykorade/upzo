#if os(iOS)
import AlarmKit
import UserNotifications

/// Whether the app can deliver wake-ups (AlarmKit and/or notifications).
enum AppSchedulingAccess {
    @MainActor
    static func canDeliverAlarms() async -> Bool {
        if AlarmManager.shared.authorizationState == .authorized {
            return true
        }
        let status = await notificationStatus()
        return status == .authorized || status == .provisional
    }

    private static func notificationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }
}
#endif
