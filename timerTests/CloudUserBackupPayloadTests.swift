#if os(iOS)
import XCTest
@testable import timer

final class CloudUserBackupPayloadTests: XCTestCase {
    func testPayloadCodableRoundTrip() throws {
        let alarm = Alarm(
            title: "Morning",
            hour: 7,
            minute: 0,
            repeatDays: [.monday, .wednesday],
            scheduleMode: .scheduled,
            isEnabled: true,
            missionType: .math,
            alarmSound: .pulse
        )
        let wakeEvent = WakeEvent(
            alarmId: alarm.id,
            completedAt: Date(timeIntervalSince1970: 1_700_000_300),
            missionType: alarm.missionType,
            responseSeconds: 300,
            alarmSound: alarm.alarmSound
        )

        let payload = CloudUserBackupPayload(
            version: CloudUserBackupPayload.currentVersion,
            modifiedAt: Date(timeIntervalSince1970: 1_700_000_000),
            appleUserID: "apple-user-123",
            alarms: [alarm],
            wakeEvents: [wakeEvent],
            onboardingCompleted: true,
            onboardingSkippedForReturningUser: false,
            onboardingProfile: OnboardingProfile(
                wakeHour: 6,
                wakeMinute: 30,
                repeatDays: [.monday, .tuesday, .wednesday, .thursday, .friday]
            ),
            commitmentCompleted: true,
            appSettings: CloudAppSettingsSnapshot(
                goalWakeHour: 6,
                goalWakeMinute: 30,
                hasGoalWakeTime: true,
                vibrationEnabled: true,
                alarmDuringMissionEnabled: false,
                snoozeEnabled: false,
                missionVerificationLevel: .normal
            ),
            notificationPrefs: CloudNotificationPrefsSnapshot(
                eveningNudgeEnabled: true,
                eveningNudgeHour: 20,
                eveningNudgeMinute: 0,
                planRemindersEnabled: false,
                finishSetupReminderEnabled: true,
                trialReminderEnabled: false,
                freeTrialNudgesEnabled: true
            ),
            subscription: CloudSubscriptionSnapshot(
                accessUntil: Date(timeIntervalSince1970: 1_800_000_000),
                purchasedProductIDs: ["com.amay.timer.monthly"]
            )
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(CloudUserBackupPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
        XCTAssertTrue(decoded.hasMeaningfulData)
    }

    func testEmptyPayloadIsNotMeaningful() {
        let payload = CloudUserBackupPayload(
            version: 1,
            modifiedAt: .distantPast,
            appleUserID: "user",
            alarms: [],
            wakeEvents: [],
            onboardingCompleted: false,
            onboardingSkippedForReturningUser: false,
            onboardingProfile: nil,
            commitmentCompleted: false,
            appSettings: CloudAppSettingsSnapshot(
                goalWakeHour: 7,
                goalWakeMinute: 0,
                hasGoalWakeTime: false,
                vibrationEnabled: true,
                alarmDuringMissionEnabled: true,
                snoozeEnabled: false,
                missionVerificationLevel: .normal
            ),
            notificationPrefs: CloudNotificationPrefsSnapshot(
                eveningNudgeEnabled: true,
                eveningNudgeHour: 20,
                eveningNudgeMinute: 0,
                planRemindersEnabled: false,
                finishSetupReminderEnabled: false,
                trialReminderEnabled: false,
                freeTrialNudgesEnabled: false
            ),
            subscription: CloudSubscriptionSnapshot(accessUntil: nil, purchasedProductIDs: [])
        )

        XCTAssertFalse(payload.hasMeaningfulData)
    }
}
#endif
