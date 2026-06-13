#if os(iOS)
import Clarity
import UIKit
import UserNotifications

extension Notification.Name {
    /// Posted on the main queue when the user opens an alarm notification.
    static let timerOpenMissionAlarm = Notification.Name("timerOpenMissionAlarm")
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        initializeClarity()
        bootstrapPendingMissionFromDisk()
        return true
    }

    private func initializeClarity() {
        var config = ClarityConfig(projectId: "x6dsfcaydk")
        #if DEBUG
        config.logLevel = .verbose
        #endif
        ClaritySDK.initialize(config: config)
    }

    @MainActor
    private func bootstrapPendingMissionFromDisk() {
        WakeSessionStore.shared.restoreIfNeeded()
        MissionRecoveryStore.shared.refreshFromDisk()

        let owedID = WakeSessionStore.shared.pendingMissionAlarmId
            ?? MissionRecoveryStore.shared.pendingMissionAlarmID

        guard let owedID else { return }
        PendingMissionRouter.shared.setPending(owedID)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        false
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["alarmId"] as? String,
              let alarmId = UUID(uuidString: idString)
        else { return }

        if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            Task { @MainActor in
                await WakeDeliveryService.shared.notificationDismissedWithoutMission(alarmId: alarmId)
            }
            return
        }

        DispatchQueue.main.async {
            PendingMissionRouter.shared.setPending(idString: idString)

            NotificationCenter.default.post(
                name: .timerOpenMissionAlarm,
                object: nil,
                userInfo: ["alarmId": idString]
            )
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let request = notification.request
        guard let alarmId = AlarmNotificationManager.alarmId(from: request.content.userInfo) else {
            completionHandler([.banner, .sound, .list])
            return
        }

        if AlarmNotificationManager.isScheduledWakeNotification(request, alarmId: alarmId) {
            AlarmAlertSessionStore.shared.beginNewAlertCycle(alarmId: alarmId)
        }

        let suppress = AlarmAlertSessionStore.shared.shouldSuppressFollowUpNotification(alarmId: alarmId)
        if suppress {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .list])
    }
}
#endif
