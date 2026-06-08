import Foundation

extension WakeHistoryStore {
    var averageWakeTimeDisplay: String? {
        guard !events.isEmpty else { return nil }
        let cal = Calendar.current
        let totalMinutes = events.reduce(0) { sum, event in
            let hour = cal.component(.hour, from: event.completedAt)
            let minute = cal.component(.minute, from: event.completedAt)
            return sum + hour * 60 + minute
        }
        let average = totalMinutes / events.count
        return Alarm.formattedTime(hour: average / 60, minute: average % 60)
    }

    var averageResponseDisplay: String? {
        let durations = events.compactMap(\.responseSeconds)
        guard !durations.isEmpty else { return nil }
        let average = durations.reduce(0, +) / durations.count
        return Self.formatDuration(seconds: average)
    }

    var favoriteMission: MissionType? {
        Self.mostFrequent(in: events.map(\.missionType))
    }

    var favoriteMissionDisplay: String? {
        favoriteMission?.title
    }

    var favoriteSound: AlarmSound? {
        Self.mostFrequent(in: events.compactMap(\.alarmSound))
    }

    var favoriteSoundDisplay: String? {
        favoriteSound?.title
    }

    var earnedBadges: [WakeBadge] {
        WakeBadgeCatalog.earned(
            streakDays: currentStreakDays,
            totalWakes: totalSuccessfulWakes,
            events: events
        )
    }

    private static func mostFrequent<T: Hashable>(in values: [T]) -> T? {
        guard !values.isEmpty else { return nil }
        let counts = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key
    }

    private static func formatDuration(seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if remainder == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m \(remainder)s"
    }
}
