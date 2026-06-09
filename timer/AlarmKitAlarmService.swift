#if os(iOS)
import ActivityKit
import AlarmKit
import Foundation
import SwiftUI
import WakeCore

enum AlarmKitAlarmService {
    static let missionRecatchInterval: TimeInterval = WakeChainPlanner.ringInterval

    /// Legacy single recatch slot (chain slot 1).
    static func recatchID(for sourceAlarmID: UUID) -> UUID {
        WakeChainPlanner.chainSlotID(for: sourceAlarmID, slot: 1)
    }

    static func sourceAlarmID(for kitOrChainID: UUID) -> UUID {
        AlarmStore.sourceAlarmIDForKitOrChainSlot(kitOrChainID)
    }

    static var isAuthorized: Bool {
        AlarmManager.shared.authorizationState == .authorized
    }

    static var shouldUseNotificationFallback: Bool {
        !isAuthorized
    }

    static var settingsStatusLine: String {
        settingsStatusLine(for: AlarmManager.shared.authorizationState)
    }

    static func settingsStatusLine(for state: AlarmManager.AuthorizationState) -> String {
        switch state {
        case .authorized:
            return "On — wake-ups use the system alarm (rings like Clock)."
        case .denied:
            return "Denied — wake-ups use notifications only. You can turn this on in Settings → Apps → Timer → Alarms."
        case .notDetermined:
            return "Not enabled — tap the button below so iOS can ask permission."
        }
    }

    static func requestAuthorization() async throws -> AlarmManager.AuthorizationState {
        try await AlarmManager.shared.requestAuthorization()
    }

    static func syncIfPossible(alarms: [Alarm]) async {
        let auth = AlarmManager.shared.authorizationState
        guard auth == .authorized else {
            if auth == .denied {
                if let remote = try? AlarmManager.shared.alarms {
                    for kit in remote {
                        try? AlarmManager.shared.cancel(id: kit.id)
                    }
                }
            }
            return
        }

        let localIds = Set(alarms.map(\.id))
        if let remote = try? AlarmManager.shared.alarms {
            for kit in remote where !localIds.contains(sourceAlarmID(for: kit.id)) {
                try? AlarmManager.shared.cancel(id: kit.id)
            }
        }

        for model in alarms where !model.isEnabled {
            try? AlarmManager.shared.cancel(id: model.id)
            cancelWakeChainSlots(for: model.id)
        }

        for model in alarms where model.isEnabled {
            do {
                try await scheduleEnabledAlarm(model)
            } catch {
                // `maximumLimitReached` or transient failures.
            }
        }
    }

    /// Schedules follow-up system rings at +30s, +60s, … from `anchor` for the active wake only.
    @discardableResult
    static func scheduleWakeChain(for model: Alarm, from anchor: Date) async -> Int {
        guard isAuthorized else { return 0 }
        cancelWakeChainSlots(for: model.id)

        var scheduled = 0
        for slot in 1 ... WakeChainPlanner.systemRingCount {
            let fire = WakeChainPlanner.systemRingDate(anchor: anchor, slot: slot)
            guard fire > Date() else { continue }

            let schedule = AlarmKit.Alarm.Schedule.fixed(fire)
            let slotID = WakeChainPlanner.chainSlotID(for: model.id, slot: slot)
            let configuration = alarmConfiguration(for: model, schedule: schedule, kitAlarmID: slotID)
            try? AlarmManager.shared.cancel(id: slotID)
            do {
                _ = try await AlarmManager.shared.schedule(id: slotID, configuration: configuration)
                scheduled += 1
            } catch {
                break
            }
        }
        return scheduled
    }

    static func cancelWakeChain(for alarmId: UUID) {
        guard isAuthorized else { return }
        let source = sourceAlarmID(for: alarmId)
        try? AlarmManager.shared.stop(id: source)
        cancelWakeChainSlots(for: source)
    }

    /// Stops any currently alerting primary or chain alarm without cancelling future follow-up slots.
    static func stopActiveAlerting(for alarmId: UUID) {
        guard isAuthorized else { return }
        let source = sourceAlarmID(for: alarmId)
        try? AlarmManager.shared.stop(id: source)
        guard let kits = try? AlarmManager.shared.alarms else { return }
        for kit in kits where sourceAlarmID(for: kit.id) == source && kit.state == .alerting {
            try? AlarmManager.shared.stop(id: kit.id)
        }
    }

    /// Whether any wake-chain slot is registered with AlarmKit for this source alarm.
    static func hasWakeChainScheduled(for alarmId: UUID) -> Bool {
        guard isAuthorized, let kits = try? AlarmManager.shared.alarms else { return false }
        let source = sourceAlarmID(for: alarmId)
        let slotIDs = Set(WakeChainPlanner.allChainSlotIDs(for: source))
        return kits.contains { slotIDs.contains($0.id) }
    }

    static func stopRecatchIfNeeded(id: UUID) {
        cancelWakeChain(for: id)
    }

    static func scheduleRecatchRing(for model: Alarm, delay: TimeInterval? = nil) async {
        let offset = max(5, delay ?? missionRecatchInterval) - WakeChainPlanner.ringInterval
        _ = await scheduleWakeChain(for: model, from: Date().addingTimeInterval(offset))
    }

    static func beginMissionRecatch(id: UUID) {
        guard let model = AlarmStore.alarmFromDisk(id: id) else { return }
        Task { _ = await scheduleWakeChain(for: model, from: Date()) }
    }

    static func restoreRepeatingSchedule(for model: Alarm) async {
        guard isAuthorized else { return }
        try? await scheduleEnabledAlarm(model)
    }

    static func restoreRepeatingSchedule(alarmId: UUID) async {
        guard let model = AlarmStore.alarmFromDisk(id: alarmId) else { return }
        await restoreRepeatingSchedule(for: model)
    }

    private static func cancelWakeChainSlots(for sourceAlarmID: UUID) {
        guard isAuthorized else { return }
        for slotID in WakeChainPlanner.allChainSlotIDs(for: sourceAlarmID) {
            try? AlarmManager.shared.cancel(id: slotID)
        }
    }

    private static func scheduleEnabledAlarm(_ model: Alarm) async throws {
        let schedule: AlarmKit.Alarm.Schedule
        switch model.scheduleMode {
        case .oneTime:
            guard let fire = model.nextFireDate(from: Date()), fire > Date() else {
                try? AlarmManager.shared.cancel(id: model.id)
                return
            }
            schedule = .fixed(fire)
        case .scheduled:
            guard !model.repeatDays.isEmpty else {
                try? AlarmManager.shared.cancel(id: model.id)
                return
            }
            let weekdays = model.repeatDays.map(\.localeWeekday)
            let relative = AlarmKit.Alarm.Schedule.Relative(
                time: AlarmKit.Alarm.Schedule.Relative.Time(hour: model.hour, minute: model.minute),
                repeats: AlarmKit.Alarm.Schedule.Relative.Recurrence.weekly(weekdays)
            )
            schedule = .relative(relative)
        }

        try? AlarmManager.shared.cancel(id: model.id)
        let configuration = alarmConfiguration(for: model, schedule: schedule)
        _ = try await AlarmManager.shared.schedule(id: model.id, configuration: configuration)
    }

    private static func alarmConfiguration(
        for model: Alarm,
        schedule: AlarmKit.Alarm.Schedule,
        kitAlarmID: UUID? = nil
    ) -> AlarmManager.AlarmConfiguration<TimerWakeAlarmMetadata> {
        let scheduledID = (kitAlarmID ?? model.id).uuidString
        let snoozeButton = AlarmButton(
            text: LocalizedStringResource(stringLiteral: "Snooze"),
            textColor: .white,
            systemImageName: "clock.arrow.circlepath"
        )
        let alert = AlarmKit.AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: "Time to wake up"),
            secondaryButton: snoozeButton,
            secondaryButtonBehavior: .countdown
        )
        let presentation = AlarmKit.AlarmPresentation(
            alert: alert,
            countdown: AlarmKit.AlarmPresentation.Countdown(
                title: LocalizedStringResource(stringLiteral: "Wake up")
            )
        )
        let attributes = AlarmKit.AlarmAttributes<TimerWakeAlarmMetadata>(
            presentation: presentation,
            metadata: nil,
            tintColor: .orange
        )
        let countdownDuration = AlarmKit.Alarm.CountdownDuration(
            preAlert: nil,
            postAlert: missionRecatchInterval
        )
        return AlarmManager.AlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: OpenWakeMissionIntent(alarmID: scheduledID),
            sound: model.alarmSound.alarmKitAlertSound
        )
    }
}

extension Weekday {
    var localeWeekday: Locale.Weekday {
        switch self {
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        case .sunday: .sunday
        }
    }
}

#endif
