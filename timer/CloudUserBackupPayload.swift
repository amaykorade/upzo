#if os(iOS)
import Foundation

/// JSON snapshot synced to the user's private iCloud (CloudKit) when signed in.
struct CloudUserBackupPayload: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var modifiedAt: Date
    var appleUserID: String

    var alarms: [Alarm]
    var wakeEvents: [WakeEvent]

    var onboardingCompleted: Bool
    var onboardingSkippedForReturningUser: Bool
    var onboardingProfile: OnboardingProfile?
    var commitmentCompleted: Bool

    var appSettings: CloudAppSettingsSnapshot
    var notificationPrefs: CloudNotificationPrefsSnapshot
    var subscription: CloudSubscriptionSnapshot

    var hasMeaningfulData: Bool {
        onboardingCompleted
            || commitmentCompleted
            || !alarms.isEmpty
            || !wakeEvents.isEmpty
    }
}

struct CloudAppSettingsSnapshot: Codable, Equatable {
    var goalWakeHour: Int
    var goalWakeMinute: Int
    var hasGoalWakeTime: Bool
    var vibrationEnabled: Bool
    var alarmDuringMissionEnabled: Bool
    var snoozeEnabled: Bool
    var missionVerificationLevel: MissionVerificationLevel
}

struct CloudNotificationPrefsSnapshot: Codable, Equatable {
    var eveningNudgeEnabled: Bool
    var eveningNudgeHour: Int
    var eveningNudgeMinute: Int
    var planRemindersEnabled: Bool
    var finishSetupReminderEnabled: Bool
    var trialReminderEnabled: Bool
    var freeTrialNudgesEnabled: Bool
}

struct CloudSubscriptionSnapshot: Codable, Equatable {
    var accessUntil: Date?
    var purchasedProductIDs: [String]
}

enum UserDataSnapshot {
    @MainActor
    static func capture(appleUserID: String) -> CloudUserBackupPayload {
        let onboarding = OnboardingStore.shared
        let settings = AlarmAppSettingsStore.shared
        let notifications = NotificationPreferencesStore.shared

        return CloudUserBackupPayload(
            version: CloudUserBackupPayload.currentVersion,
            modifiedAt: CloudKitUserDataSync.localModifiedAt,
            appleUserID: appleUserID,
            alarms: AlarmStore.loadAlarmsFromDisk(),
            wakeEvents: WakeHistoryStore.loadEventsFromDisk(),
            onboardingCompleted: onboarding.hasCompletedOnboarding,
            onboardingSkippedForReturningUser: onboarding.skippedOnboardingForReturningUser,
            onboardingProfile: onboarding.profile,
            commitmentCompleted: CommitmentStore.hasCompletedCommitment,
            appSettings: CloudAppSettingsSnapshot(
                goalWakeHour: settings.goalWakeHour,
                goalWakeMinute: settings.goalWakeMinute,
                hasGoalWakeTime: settings.hasGoalWakeTime,
                vibrationEnabled: settings.vibrationEnabled,
                alarmDuringMissionEnabled: settings.alarmDuringMissionEnabled,
                snoozeEnabled: settings.snoozeEnabled,
                missionVerificationLevel: settings.missionVerificationLevel
            ),
            notificationPrefs: CloudNotificationPrefsSnapshot(
                eveningNudgeEnabled: notifications.eveningNudgeEnabled,
                eveningNudgeHour: notifications.eveningNudgeHour,
                eveningNudgeMinute: notifications.eveningNudgeMinute,
                planRemindersEnabled: notifications.planRemindersEnabled,
                finishSetupReminderEnabled: notifications.finishSetupReminderEnabled,
                trialReminderEnabled: notifications.trialReminderEnabled,
                freeTrialNudgesEnabled: notifications.freeTrialNudgesEnabled
            ),
            subscription: SubscriptionStore.shared.cloudBackupSnapshot
        )
    }

    @MainActor
    static func apply(
        _ payload: CloudUserBackupPayload,
        alarmStore: AlarmStore,
        wakeHistory: WakeHistoryStore
    ) async {
        CloudKitUserDataSync.isApplyingRemoteSnapshot = true
        defer { CloudKitUserDataSync.isApplyingRemoteSnapshot = false }

        AlarmStore.saveAlarmsToDisk(payload.alarms)
        WakeHistoryStore.saveEventsToDisk(payload.wakeEvents)
        alarmStore.reloadFromDisk()
        wakeHistory.reloadFromDisk()

        let onboarding = OnboardingStore.shared
        onboarding.applyCloudBackup(
            completed: payload.onboardingCompleted,
            skippedForReturningUser: payload.onboardingSkippedForReturningUser,
            profile: payload.onboardingProfile
        )
        CommitmentStore.hasCompletedCommitment = payload.commitmentCompleted

        AlarmAppSettingsStore.shared.applyCloudBackup(payload.appSettings)
        NotificationPreferencesStore.shared.applyCloudBackup(payload.notificationPrefs)
        SubscriptionStore.shared.applyCloudBackup(payload.subscription)

        CloudKitUserDataSync.setLocalModifiedAt(payload.modifiedAt)
        await alarmStore.rescheduleNotifications()
    }
}
#endif
