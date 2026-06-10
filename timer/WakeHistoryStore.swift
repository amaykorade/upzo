import Foundation
import Combine

@MainActor
final class WakeHistoryStore: ObservableObject {
    @Published private(set) var events: [WakeEvent] = []

    private let fileURL: URL
    private let isPreview: Bool

    init(preview: Bool = false, initialEvents: [WakeEvent] = []) {
        self.isPreview = preview
        self.fileURL = Self.eventsFileURL()

        if preview {
            self.events = initialEvents.sorted { $0.completedAt > $1.completedAt }
        } else {
            self.events = Self.loadEvents(from: fileURL)
        }
    }

    static func mock() -> WakeHistoryStore {
        let cal = Calendar.current
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        let id = UUID()
        return WakeHistoryStore(
            preview: true,
            initialEvents: [
                WakeEvent(alarmId: id, completedAt: today, missionType: .shake, responseSeconds: 42, alarmSound: .classic),
                WakeEvent(alarmId: id, completedAt: cal.date(byAdding: .hour, value: -3, to: today)!, missionType: .shake, responseSeconds: 55, alarmSound: .classic),
                WakeEvent(alarmId: id, completedAt: yesterday, missionType: .text, responseSeconds: 88, alarmSound: .pulse),
                WakeEvent(alarmId: id, completedAt: twoDaysAgo, missionType: .photo, responseSeconds: 120, alarmSound: .pulse),
            ]
        )
    }

    func recordCompletion(
        alarmId: UUID,
        missionType: MissionType,
        alarmSound: AlarmSound,
        at date: Date = Date()
    ) {
        let responseSeconds = MissionTimingStore.shared.consumeResponseSeconds(for: alarmId, completedAt: date)
        let entry = WakeEvent(
            alarmId: alarmId,
            completedAt: date,
            missionType: missionType,
            responseSeconds: responseSeconds,
            alarmSound: alarmSound
        )
        events.insert(entry, at: 0)
        events.sort { $0.completedAt > $1.completedAt }
        persistIfNeeded()
    }

    /// Consecutive calendar days with at least one success, counting backward from today (today may be skipped if still empty).
    var currentStreakDays: Int {
        Self.computeStreak(from: events, relativeTo: Date(), calendar: .current)
    }

    var totalSuccessfulWakes: Int {
        events.count
    }

    var successfulWakesLast7Days: Int {
        let cal = Calendar.current
        guard let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        return events.filter { $0.completedAt >= weekAgo }.count
    }

    func hadWake(onDayContaining date: Date) -> Bool {
        let cal = Calendar.current
        let target = cal.startOfDay(for: date)
        return events.contains { cal.isDate($0.completedAt, inSameDayAs: target) }
    }

    /// Completed missions on the current local calendar day (newest first among today’s subset).
    var wakeEventsToday: [WakeEvent] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return events.filter { $0.completedAt >= start }
    }

    /// Whether a mission was logged for this alarm at or after `date` (e.g. after AlarmKit began alerting).
    func hasCompletion(forAlarmId alarmId: UUID, onOrAfter date: Date) -> Bool {
        events.contains { $0.alarmId == alarmId && $0.completedAt >= date }
    }

    func reloadFromDisk() {
        guard !isPreview else { return }
        events = Self.loadEvents(from: fileURL)
    }

    private func persistIfNeeded() {
        guard !isPreview else { return }
        Self.saveEvents(events, to: fileURL)
#if os(iOS)
        CloudKitUserDataSync.markLocalDataChanged()
#endif
    }

    static func loadEventsFromDisk() -> [WakeEvent] {
        loadEvents(from: eventsFileURL())
    }

    static func saveEventsToDisk(_ events: [WakeEvent]) {
        saveEvents(events, to: eventsFileURL())
    }

    private static func eventsFileURL() -> URL {
        let fm = FileManager.default
        let base: URL
        do {
            base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            base = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        return base.appendingPathComponent("wake_history.json")
    }

    private static func loadEvents(from url: URL) -> [WakeEvent] {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([WakeEvent].self, from: data)
            return decoded.sorted { $0.completedAt > $1.completedAt }
        } catch {
            return []
        }
    }

    private static func saveEvents(_ events: [WakeEvent], to url: URL) {
        do {
            let data = try JSONEncoder().encode(events.sorted { $0.completedAt > $1.completedAt })
            try data.write(to: url, options: .atomic)
        } catch {}
    }

    nonisolated private static func computeStreak(from events: [WakeEvent], relativeTo now: Date, calendar: Calendar) -> Int {
        let dayStarts: Set<TimeInterval> = Set(
            events.map { calendar.startOfDay(for: $0.completedAt).timeIntervalSince1970 }
        )

        var streak = 0
        var offset = 0

        while offset < 400 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { break }
            let start = calendar.startOfDay(for: day).timeIntervalSince1970

            if dayStarts.contains(start) {
                streak += 1
                offset += 1
            } else if offset == 0 {
                offset += 1
            } else {
                break
            }
        }

        return streak
    }
}
