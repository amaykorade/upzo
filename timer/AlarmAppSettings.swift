import Foundation
import Combine

enum MissionVerificationLevel: String, CaseIterable, Codable, Identifiable {
    case normal
    case strict

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "Normal"
        case .strict: "Strict"
        }
    }

    var detail: String {
        switch self {
        case .normal:
            return "Easier math, fewer steps and pushups, library sky photos allowed."
        case .strict:
            return "Harder math, more steps and pushups, camera-only outdoor sky photo, longer phrases."
        }
    }
}

@MainActor
final class AlarmAppSettingsStore: ObservableObject {
    static let shared = AlarmAppSettingsStore()

    private enum Keys {
        static let goalWakeHour = "alarmSettings.goalWakeHour"
        static let goalWakeMinute = "alarmSettings.goalWakeMinute"
        static let goalWakeIsSet = "alarmSettings.goalWakeIsSet"
        static let vibrationEnabled = "alarmSettings.vibrationEnabled"
        static let alarmDuringMission = "alarmSettings.alarmDuringMission"
        static let snoozeEnabled = "alarmSettings.snoozeEnabled"
        static let verificationLevel = "alarmSettings.verificationLevel"
    }

    @Published var goalWakeHour: Int {
        didSet { UserDefaults.standard.set(goalWakeHour, forKey: Keys.goalWakeHour) }
    }

    @Published var goalWakeMinute: Int {
        didSet { UserDefaults.standard.set(goalWakeMinute, forKey: Keys.goalWakeMinute) }
    }

    @Published var hasGoalWakeTime: Bool {
        didSet { UserDefaults.standard.set(hasGoalWakeTime, forKey: Keys.goalWakeIsSet) }
    }

    @Published var vibrationEnabled: Bool {
        didSet { UserDefaults.standard.set(vibrationEnabled, forKey: Keys.vibrationEnabled) }
    }

    @Published var alarmDuringMissionEnabled: Bool {
        didSet { UserDefaults.standard.set(alarmDuringMissionEnabled, forKey: Keys.alarmDuringMission) }
    }

    @Published var snoozeEnabled: Bool {
        didSet { UserDefaults.standard.set(snoozeEnabled, forKey: Keys.snoozeEnabled) }
    }

    @Published var missionVerificationLevel: MissionVerificationLevel {
        didSet { UserDefaults.standard.set(missionVerificationLevel.rawValue, forKey: Keys.verificationLevel) }
    }

    private init() {
        let defaults = UserDefaults.standard
        goalWakeHour = defaults.object(forKey: Keys.goalWakeHour) as? Int ?? 7
        goalWakeMinute = defaults.object(forKey: Keys.goalWakeMinute) as? Int ?? 0
        hasGoalWakeTime = defaults.bool(forKey: Keys.goalWakeIsSet)
        vibrationEnabled = defaults.object(forKey: Keys.vibrationEnabled) as? Bool ?? true
        alarmDuringMissionEnabled = defaults.object(forKey: Keys.alarmDuringMission) as? Bool ?? true
        snoozeEnabled = defaults.object(forKey: Keys.snoozeEnabled) as? Bool ?? false
        let levelRaw = defaults.string(forKey: Keys.verificationLevel) ?? MissionVerificationLevel.normal.rawValue
        missionVerificationLevel = MissionVerificationLevel(rawValue: levelRaw) ?? .normal
    }

    var goalWakeTimeDisplay: String {
        Alarm.formattedTime(hour: goalWakeHour, minute: goalWakeMinute)
    }

    func saveGoalWakeTime(hour: Int, minute: Int) {
        goalWakeHour = hour
        goalWakeMinute = minute
        hasGoalWakeTime = true
    }

    func clearGoalWakeTime() {
        hasGoalWakeTime = false
    }

    var missionRequirements: MissionRequirements {
        MissionRequirements(verificationLevel: missionVerificationLevel)
    }
}
