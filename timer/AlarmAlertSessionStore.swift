#if os(iOS)
import Foundation

/// Tracks the current wake-up alert cycle so we can suppress stale follow-up notifications
/// after the user has already finished the mission.
@MainActor
final class AlarmAlertSessionStore {
    static let shared = AlarmAlertSessionStore()

    private var cycleBeganAt: [UUID: Date] = [:]
    private var completedAt: [UUID: Date] = [:]

    private init() {}

    func beginNewAlertCycle(alarmId: UUID) {
        cycleBeganAt[alarmId] = Date()
        completedAt.removeValue(forKey: alarmId)
    }

    func markMissionCompleted(alarmId: UUID) {
        completedAt[alarmId] = Date()
    }

    func cycleBeganAt(for alarmId: UUID) -> Date? {
        cycleBeganAt[alarmId]
    }

    /// Suppresses follow-up delivery only when the mission was completed during the current alert cycle.
    func shouldSuppressFollowUpNotification(alarmId: UUID) -> Bool {
        guard let finished = completedAt[alarmId],
              let cycleStart = cycleBeganAt[alarmId]
        else { return false }
        return finished >= cycleStart
    }
}
#endif
