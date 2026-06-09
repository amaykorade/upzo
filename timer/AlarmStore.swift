import Foundation
import Combine

@MainActor
final class AlarmStore: ObservableObject {
    @Published private(set) var alarms: [Alarm] = []

    private let fileURL: URL
    private var isPreview: Bool

    init(preview: Bool = false, initialAlarms: [Alarm] = []) {
        self.isPreview = preview
        self.fileURL = Self.alarmsFileURL()

        if preview {
            self.alarms = initialAlarms
        } else {
            self.alarms = Self.loadAlarms(from: fileURL)
            if self.alarms == [] {
                // Start empty for first launch; the UI will guide the user.
            }
#if os(iOS)
            rescheduleNotificationsOnLaunch()
#endif
        }
    }

    static func mock() -> AlarmStore {
        AlarmStore(
            preview: true,
            initialAlarms: [
                Alarm(title: "Morning", hour: 7, minute: 30, repeatDays: Weekday.allCases, isEnabled: true, missionType: .shake),
                Alarm(title: "", hour: 8, minute: 0, repeatDays: [.monday, .wednesday, .friday], isEnabled: true, missionType: .photo),
            ]
        )
    }

    func upsert(_ alarm: Alarm) {
#if os(iOS)
        if alarm.isEnabled && !SubscriptionStore.shared.isPremium {
            return
        }
#endif
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx] = alarm
        } else {
            alarms.append(alarm)
        }
        persistIfNeeded()
    }

    func setEnabled(_ alarmID: UUID, isEnabled: Bool) {
#if os(iOS)
        if isEnabled && !SubscriptionStore.shared.isPremium {
            return
        }
#endif
        guard let idx = alarms.firstIndex(where: { $0.id == alarmID }) else { return }
        alarms[idx].isEnabled = isEnabled
#if os(iOS)
        if !isEnabled {
            Task { await AlarmNotificationManager.shared.stopChaser(for: alarmID) }
        }
#endif
        persistIfNeeded()
    }

    func delete(_ alarmID: UUID) {
        alarms.removeAll { $0.id == alarmID }
#if os(iOS)
        Task { await AlarmNotificationManager.shared.stopChaser(for: alarmID) }
#endif
        persistIfNeeded()
    }

    func alarm(id: UUID) -> Alarm? {
        alarms.first { $0.id == id }
    }

#if os(iOS)
    /// Turns off all alarms when Plus subscription expires so rings stop until the user resubscribes.
    func disableAllForExpiredSubscription() {
        var changed = false
        for index in alarms.indices where alarms[index].isEnabled {
            alarms[index].isEnabled = false
            changed = true
        }
        guard changed else { return }
        persistIfNeeded()
    }
#endif

    private func persistIfNeeded() {
        guard !isPreview else { return }
        Self.saveAlarms(alarms, to: fileURL)
#if os(iOS)
        Task { await ensurePermissionsAndReschedule() }
#endif
    }

#if os(iOS)
    /// Asks for AlarmKit + notification permissions the first time the user saves/enables an alarm.
    private func ensurePermissionsAndReschedule() async {
        if alarms.contains(where: \.isEnabled) {
            _ = await AlarmPermissions.ensureSchedulingPermissions()
        }
        await rescheduleNotifications()
    }
#endif

    private static func alarmsFileURL() -> URL {
        let fm = FileManager.default
        let base: URL
        do {
            base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            // Fall back to documents in case Application Support fails.
            base = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        return base.appendingPathComponent("alarms.json")
    }

    private static func loadAlarms(from url: URL) -> [Alarm] {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Alarm].self, from: data)
            return decoded.sorted { alarmTimeSortKey($0) < alarmTimeSortKey($1) }
        } catch {
            return []
        }
    }

    private static func saveAlarms(_ alarms: [Alarm], to url: URL) {
        do {
            let data = try JSONEncoder().encode(
                alarms.sorted { alarmTimeSortKey($0) < alarmTimeSortKey($1) }
            )
            try data.write(to: url, options: .atomic)
        } catch {
            // For v1, ignore persistence failures rather than crashing.
        }
    }

    nonisolated private static func alarmTimeSortKey(_ alarm: Alarm) -> Int {
        alarm.hour * 60 + alarm.minute
    }

#if os(iOS)
    /// Loads a single alarm from disk without creating a store (safe from AppDelegate / notification handlers).
    static func alarmFromDisk(id: UUID) -> Alarm? {
        loadAlarms(from: alarmsFileURL()).first { $0.id == id }
    }

    /// Maps a main or wake-chain AlarmKit id back to the alarm in `alarms.json`.
    static func sourceAlarmIDForKitOrChainSlot(_ kitOrChainID: UUID) -> UUID {
        if alarmFromDisk(id: kitOrChainID) != nil {
            return kitOrChainID
        }
        for alarm in loadAlarms(from: alarmsFileURL()) {
            for slot in 1 ... WakeChainPlanner.systemRingCount {
                if WakeChainPlanner.chainSlotID(for: alarm.id, slot: slot) == kitOrChainID {
                    return alarm.id
                }
            }
        }
        return kitOrChainID
    }

    func rescheduleNotifications() async {
        await WakeDeliveryService.shared.syncAllAlarms(alarms)
    }

    func rescheduleNotificationsOnLaunch() {
        Task {
            WakeSessionStore.shared.restoreIfNeeded()
            if WakeSessionStore.shared.pendingMissionAlarmId != nil {
                // Let the mission UI open before rescheduling AlarmKit alarms.
                try? await Task.sleep(for: .seconds(3))
            }
            // If the user is returning to the app, surface the permission prompts they may not have completed.
            if alarms.contains(where: \.isEnabled) {
                _ = await AlarmPermissions.ensureSchedulingPermissions()
            }
            await rescheduleNotifications()
        }
    }

    /// Call after notification or AlarmKit permission changes so delivery matches the current mode.
    func syncAlarmDeliveryToSystem() async {
        await rescheduleNotifications()
    }
#endif
}

