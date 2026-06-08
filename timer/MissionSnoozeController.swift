#if os(iOS)
import Foundation

/// Tracks one 5-minute snooze per alarm alert cycle.
@MainActor
final class MissionSnoozeController {
    static let shared = MissionSnoozeController()

    private var snoozeUsedForAlarm = Set<UUID>()

    private init() {}

    func canSnooze(alarmId: UUID) -> Bool {
        !snoozeUsedForAlarm.contains(alarmId)
    }

    func markSnoozeUsed(for alarmId: UUID) {
        snoozeUsedForAlarm.insert(alarmId)
    }

    func clearSnoozeUsage(for alarmId: UUID) {
        snoozeUsedForAlarm.remove(alarmId)
    }

    func scheduleSnooze(for alarmId: UUID, sound: AlarmSound) async {
        markSnoozeUsed(for: alarmId)
        await AlarmNotificationManager.shared.scheduleSnoozeNotification(
            forAlarmId: alarmId,
            sound: sound,
            delay: 5 * 60
        )
    }
}
#endif
