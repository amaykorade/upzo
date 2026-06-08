import Foundation
import Combine

@MainActor
final class NotificationPreferencesStore: ObservableObject {
    static let shared = NotificationPreferencesStore()

    private enum Keys {
        static let eveningNudgeEnabled = "notificationPrefs.eveningNudgeEnabled"
        static let eveningNudgeHour = "notificationPrefs.eveningNudgeHour"
        static let eveningNudgeMinute = "notificationPrefs.eveningNudgeMinute"
        static let planRemindersEnabled = "notificationPrefs.planRemindersEnabled"
        static let finishSetupReminderEnabled = "notificationPrefs.finishSetupReminderEnabled"
        static let trialReminderEnabled = "notificationPrefs.trialReminderEnabled"
        static let freeTrialNudgesEnabled = "notificationPrefs.freeTrialNudgesEnabled"
    }

    @Published var eveningNudgeEnabled: Bool {
        didSet { UserDefaults.standard.set(eveningNudgeEnabled, forKey: Keys.eveningNudgeEnabled) }
    }

    @Published var eveningNudgeHour: Int {
        didSet { UserDefaults.standard.set(eveningNudgeHour, forKey: Keys.eveningNudgeHour) }
    }

    @Published var eveningNudgeMinute: Int {
        didSet { UserDefaults.standard.set(eveningNudgeMinute, forKey: Keys.eveningNudgeMinute) }
    }

    @Published var planRemindersEnabled: Bool {
        didSet { UserDefaults.standard.set(planRemindersEnabled, forKey: Keys.planRemindersEnabled) }
    }

    @Published var finishSetupReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(finishSetupReminderEnabled, forKey: Keys.finishSetupReminderEnabled) }
    }

    @Published var trialReminderEnabled: Bool {
        didSet { UserDefaults.standard.set(trialReminderEnabled, forKey: Keys.trialReminderEnabled) }
    }

    @Published var freeTrialNudgesEnabled: Bool {
        didSet { UserDefaults.standard.set(freeTrialNudgesEnabled, forKey: Keys.freeTrialNudgesEnabled) }
    }

    private init() {
        let defaults = UserDefaults.standard
        eveningNudgeEnabled = defaults.object(forKey: Keys.eveningNudgeEnabled) as? Bool ?? true
        eveningNudgeHour = defaults.object(forKey: Keys.eveningNudgeHour) as? Int ?? 20
        eveningNudgeMinute = defaults.object(forKey: Keys.eveningNudgeMinute) as? Int ?? 0
        planRemindersEnabled = defaults.object(forKey: Keys.planRemindersEnabled) as? Bool ?? false
        finishSetupReminderEnabled = defaults.object(forKey: Keys.finishSetupReminderEnabled) as? Bool ?? false
        trialReminderEnabled = defaults.object(forKey: Keys.trialReminderEnabled) as? Bool ?? false
        freeTrialNudgesEnabled = defaults.object(forKey: Keys.freeTrialNudgesEnabled) as? Bool ?? false
    }

    var eveningNudgeTimeDisplay: String {
        Alarm.formattedTime(hour: eveningNudgeHour, minute: eveningNudgeMinute)
    }

    func saveEveningNudgeTime(hour: Int, minute: Int) {
        eveningNudgeHour = hour
        eveningNudgeMinute = minute
    }

    /// Example copy: tomorrow's alarm & mission at 8:00 PM (evening delivery time).
    func eveningNudgeDescription(missionTitle: String?) -> String {
        let mission = missionTitle ?? "mission"
        return "Tomorrow's alarm & \(mission) at \(eveningNudgeTimeDisplay)."
    }
}
