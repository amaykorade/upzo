#if os(iOS)
import Combine
import Foundation

/// Persists an in-progress mission so app termination (swipe from recents) can recover it on next launch.
@MainActor
final class MissionRecoveryStore: ObservableObject {
    static let shared = MissionRecoveryStore()

    @Published private(set) var pendingMissionAlarmID: UUID?

    private enum Keys {
        static let alarmID = "missionRecovery.pendingAlarmID"
        static let startedAt = "missionRecovery.startedAt"
    }

    private let defaults = UserDefaults.standard
    private let expirySeconds: TimeInterval = 30 * 60

    private init() {
        restoreFromDiskIfNeeded()
    }

    func markMissionActive(alarmId: UUID, at date: Date = Date()) {
        pendingMissionAlarmID = alarmId
        defaults.set(alarmId.uuidString, forKey: Keys.alarmID)
        defaults.set(date.timeIntervalSince1970, forKey: Keys.startedAt)
    }

    func clear() {
        pendingMissionAlarmID = nil
        defaults.removeObject(forKey: Keys.alarmID)
        defaults.removeObject(forKey: Keys.startedAt)
    }

    func refreshFromDisk() {
        restoreFromDiskIfNeeded()
    }

    private func restoreFromDiskIfNeeded() {
        guard let idString = defaults.string(forKey: Keys.alarmID),
              let id = UUID(uuidString: idString)
        else {
            clear()
            return
        }

        let startedAt = defaults.double(forKey: Keys.startedAt)
        guard startedAt > 0 else {
            clear()
            return
        }

        let age = Date().timeIntervalSince1970 - startedAt
        guard age <= expirySeconds else {
            clear()
            return
        }

        pendingMissionAlarmID = id
    }
}
#endif
