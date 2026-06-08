import Foundation
import Combine

@MainActor
final class OnboardingStore: ObservableObject {
    static let shared = OnboardingStore()

    private enum Keys {
        static let completed = "onboarding.completed"
        static let profileJSON = "onboarding.profile"
        static let skippedForReturningUser = "onboarding.skippedForReturningUser"
    }

    @Published private(set) var profile: OnboardingProfile?
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.completed) }
    }

    /// True when the user chose “Already have an account?” and skipped the questionnaire.
    @Published private(set) var skippedOnboardingForReturningUser: Bool {
        didSet {
            UserDefaults.standard.set(skippedOnboardingForReturningUser, forKey: Keys.skippedForReturningUser)
        }
    }

    private init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.completed)
        skippedOnboardingForReturningUser = UserDefaults.standard.bool(forKey: Keys.skippedForReturningUser)
        profile = Self.loadProfile()
    }

    func saveProfile(_ profile: OnboardingProfile) {
        var copy = profile
        copy.completedAt = Date()
        self.profile = copy
        if let data = try? JSONEncoder().encode(copy) {
            UserDefaults.standard.set(data, forKey: Keys.profileJSON)
        }
    }

    /// Applies onboarding answers to app settings. First alarm is created when the main app opens.
    func applyProfile(
        _ profile: OnboardingProfile,
        appSettings: AlarmAppSettingsStore,
        alarmStore: AlarmStore,
        createFirstAlarm: Bool = false
    ) {
        saveProfile(profile)
        applySettings(from: profile, appSettings: appSettings)

        guard createFirstAlarm else { return }
        createStarterAlarmIfNeeded(alarmStore: alarmStore, appSettings: appSettings)
    }

    func applySettings(from profile: OnboardingProfile, appSettings: AlarmAppSettingsStore) {
        appSettings.saveGoalWakeTime(hour: profile.wakeHour, minute: profile.wakeMinute)
        appSettings.missionVerificationLevel = profile.strictness?.verificationLevel ?? .normal

        let heavySnoozer = profile.bedNegotiation == .almostAlways
            || profile.backToSleep == .often
            || profile.snoozeFrequency == .threePlus
            || profile.snoozeFrequency == .untilLate
            || profile.morningStruggle == .snooze
        appSettings.snoozeEnabled = !heavySnoozer
        appSettings.alarmDuringMissionEnabled = true
        appSettings.vibrationEnabled = true
    }

    /// Creates the personalized alarm from onboarding when the user reaches the main app.
    func createStarterAlarmIfNeeded(alarmStore: AlarmStore, appSettings: AlarmAppSettingsStore) {
        guard let profile else { return }
        guard alarmStore.alarms.isEmpty else { return }

        let days = profile.repeatDays.isEmpty ? Array(OnboardingProfile.defaultWeekdayPreset) : profile.repeatDays
        let alarm = Alarm(
            title: "",
            hour: profile.wakeHour,
            minute: profile.wakeMinute,
            repeatDays: days.sorted(),
            scheduleMode: .scheduled,
            isEnabled: true,
            missionType: profile.recommendedMission,
            alarmSound: .classic
        )
        alarmStore.upsert(alarm)
    }

    func markCompleted() {
        skippedOnboardingForReturningUser = false
        hasCompletedOnboarding = true
    }

    /// Skips the questionnaire for users who sign in with an existing account.
    func markSkippedForReturningUser() {
        skippedOnboardingForReturningUser = true
        hasCompletedOnboarding = true
    }

    func resetForRetake() {
        hasCompletedOnboarding = false
        skippedOnboardingForReturningUser = false
        profile = nil
        UserDefaults.standard.removeObject(forKey: Keys.profileJSON)
#if os(iOS)
        CommitmentStore.reset()
#endif
    }

    private static func loadProfile() -> OnboardingProfile? {
        guard let data = UserDefaults.standard.data(forKey: Keys.profileJSON) else { return nil }
        return try? JSONDecoder().decode(OnboardingProfile.self, from: data)
    }
}
