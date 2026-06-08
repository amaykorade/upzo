#if os(iOS)
import Foundation
import UserNotifications

/// Schedules local notification alarms and short audible follow-up pings.
final class AlarmNotificationManager {
    static let shared = AlarmNotificationManager()

    private static let primaryPrefix = "timer.alarm."
    private static let chaserPrefix = "timer.chaser."
    private static let sustainPrefix = "timer.sustain."
    private static let wakeChainPrefix = "timer.wakechain."

    private let chaserFirstDelay: TimeInterval = 5
    private let chaserStep: TimeInterval = 20
    private let chaserCountFull = 20

    private let sustainStep: TimeInterval = 6
    private let sustainCountFull = 12

    private init() {}

    // MARK: - Authorization

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                continuation.resume(returning: ok)
            }
        }
    }

    // MARK: - Primary schedule (notification-only mode)

    func schedulePrimaryAlarms(_ alarms: [Alarm]) async {
        guard await isAuthorized() else { return }
        await cancelPrimaryAlarms()

        let center = UNUserNotificationCenter.current()
        for alarm in alarms where alarm.isEnabled {
            if alarm.scheduleMode == .oneTime {
                await addOneTimePrimary(for: alarm, center: center)
            } else {
                for weekday in alarm.repeatDays {
                    var components = DateComponents()
                    components.weekday = calendarWeekday(for: weekday)
                    components.hour = alarm.hour
                    components.minute = alarm.minute
                    try? await center.add(makeRequest(
                        id: "\(Self.primaryPrefix)\(alarm.id.uuidString).w\(calendarWeekday(for: weekday))",
                        alarmId: alarm.id,
                        sound: alarm.alarmSound.notificationSound,
                        title: "Time to wake up",
                        body: "Mission: \(alarm.missionType.title). Tap to start your wake-up mission.",
                        tag: nil,
                        trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    ))
                }
            }
        }
        await scheduleSustainStack(for: alarms, count: sustainCountFull, step: sustainStep)
    }

    // MARK: - Wake chain (AlarmKit mode): app sound between system rings

    /// Notifications at +15s, +45s, … between system rings at +30s, +60s, …
    func scheduleWakeChain(for alarm: Alarm, from anchor: Date) async {
        guard await canDeliverSound() else { return }
        await cancelWakeChain(for: alarm.id)

        let sound = alarm.alarmSound.reliableNotificationSound
        for gapIndex in 0 ..< WakeChainPlanner.systemRingCount {
            let fire = WakeChainPlanner.notificationDate(anchor: anchor, gapIndex: gapIndex)
            let delay = fire.timeIntervalSinceNow
            guard delay >= 2 else { continue }

            try? await UNUserNotificationCenter.current().add(makeRequest(
                id: "\(Self.wakeChainPrefix)\(alarm.id.uuidString).\(gapIndex)",
                alarmId: alarm.id,
                sound: sound,
                title: "Time to wake up",
                body: "Complete your wake-up mission. Tap to open.",
                tag: "wakeChain",
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            ))
        }
    }

    func hasWakeChain(for alarmId: UUID) async -> Bool {
        let needle = "\(Self.wakeChainPrefix)\(alarmId.uuidString)."
        let pending = await pendingRequests()
        return pending.contains { $0.identifier.hasPrefix(needle) }
    }

    func cancelWakeChain(for alarmId: UUID) async {
        await cancelRequests(withPrefix: "\(Self.wakeChainPrefix)\(alarmId.uuidString).")
    }

    func clearDeliveredWakeAlerts(for alarmId: UUID) async {
        let delivered = await deliveredNotifications()
        let ids = delivered
            .map(\.request)
            .filter { Self.isFollowUp($0, alarmId: alarmId) || Self.isWakeChain($0, alarmId: alarmId) }
            .map(\.identifier)
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    private static func isWakeChain(_ request: UNNotificationRequest, alarmId: UUID) -> Bool {
        request.identifier.hasPrefix("\(wakeChainPrefix)\(alarmId.uuidString).")
    }

    // MARK: - Notification-only dismiss follow-ups

    func scheduleDismissChasers(for alarm: Alarm) async {
        guard await isAuthorized() else { return }
        await cancelRequests(withPrefix: "\(Self.chaserPrefix)\(alarm.id.uuidString).")

        let sound = alarm.alarmSound.reliableNotificationSound
        for i in 1 ... chaserCountFull {
            let delay = i == 1 ? chaserFirstDelay : chaserFirstDelay + chaserStep * Double(i - 1)
            try? await UNUserNotificationCenter.current().add(makeRequest(
                id: "\(Self.chaserPrefix)\(alarm.id.uuidString).\(i)",
                alarmId: alarm.id,
                sound: sound,
                title: "Wake-up mission",
                body: "You still need to complete your mission. Tap to open.",
                tag: "chaser",
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            ))
        }
    }

    // MARK: - Snooze & test

    func scheduleSnoozeNotification(forAlarmId alarmId: UUID, sound: AlarmSound, delay: TimeInterval) async {
        guard await isAuthorized() else { return }
        let id = "\(Self.primaryPrefix)snooze.\(alarmId.uuidString).\(UUID().uuidString)"
        try? await UNUserNotificationCenter.current().add(makeRequest(
            id: id,
            alarmId: alarmId,
            sound: sound.notificationSound,
            title: "Snooze",
            body: "Your wake-up mission is ready. Tap to open.",
            tag: "snooze",
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(60, delay), repeats: false)
        ))
    }

    func scheduleTestNotification(forAlarmId alarmId: UUID, sound: AlarmSound, delay: TimeInterval = 10) async {
        guard await isAuthorized() else { return }
        let id = "\(Self.primaryPrefix)test.\(UUID().uuidString)"
        try? await UNUserNotificationCenter.current().add(makeRequest(
            id: id,
            alarmId: alarmId,
            sound: sound.notificationSound,
            title: "Test alarm",
            body: "Tap to open your mission.",
            tag: nil,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(5, delay), repeats: false)
        ))
    }

    // MARK: - Cancel

    func cancelPrimaryAlarms() async {
        let pending = await pendingRequests()
        let ids = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.primaryPrefix) && !$0.contains(".test.") }
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        await cancelSustainBackups()
    }

    func cancelFollowUps(for alarmId: UUID) async {
        await cancelWakeChain(for: alarmId)
        await cancelRequests(withPrefix: "\(Self.chaserPrefix)\(alarmId.uuidString).")
        await cancelSustainBackups(for: alarmId)
        await cancelSnooze(for: alarmId)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["\(Self.primaryPrefix)\(alarmId.uuidString).once"]
        )
        let delivered = await deliveredNotifications()
        let ids = delivered
            .map(\.request)
            .filter { Self.isFollowUp($0, alarmId: alarmId) }
            .map(\.identifier)
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// Legacy name used by mission audio — cancels sustain pings for one alarm.
    func cancelSustainNotifications(for alarmId: UUID) async {
        await cancelSustainBackups(for: alarmId)
    }

    func stopChaser(for alarmId: UUID) async {
        await cancelRequests(withPrefix: "\(Self.chaserPrefix)\(alarmId.uuidString).")
    }

    // MARK: - AppDelegate helpers

    static func isScheduledWakeNotification(_ request: UNNotificationRequest, alarmId expectedId: UUID) -> Bool {
        guard let parsed = alarmId(from: request.content.userInfo), parsed == expectedId else { return false }
        return !isFollowUp(request, alarmId: expectedId)
    }

    static func isFollowUpNotification(_ request: UNNotificationRequest, alarmId expectedId: UUID) -> Bool {
        isFollowUp(request, alarmId: expectedId)
    }

    static func alarmId(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let idString = userInfo["alarmId"] as? String else { return nil }
        return UUID(uuidString: idString)
    }

    // MARK: - Private

    private func isAuthorized() async -> Bool {
        let status = await authorizationStatus()
        return status == .authorized || status == .provisional
    }

    private func canDeliverSound() async -> Bool {
        guard await isAuthorized() else { return false }
        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.soundSetting == .enabled)
            }
        }
    }

    private func addOneTimePrimary(for alarm: Alarm, center: UNUserNotificationCenter) async {
        guard let fire = alarm.nextFireDate(from: Date()) else { return }
        let components = Calendar.current.dateComponents(
            [.calendar, .year, .month, .day, .hour, .minute],
            from: fire
        )
        try? await center.add(makeRequest(
            id: "\(Self.primaryPrefix)\(alarm.id.uuidString).once",
            alarmId: alarm.id,
            sound: alarm.alarmSound.notificationSound,
            title: "Time to wake up",
            body: "Mission: \(alarm.missionType.title). Tap to start your wake-up mission.",
            tag: nil,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        ))
    }

    private func scheduleSustainStack(for alarms: [Alarm], count: Int, step: TimeInterval) async {
        let now = Date()
        for alarm in alarms where alarm.isEnabled {
            guard let fire = alarm.nextFireDate(from: now), fire > now else { continue }
            for index in 1 ... count {
                let delay = fire.timeIntervalSince(now) + Double(index) * step
                guard delay > 0 else { continue }
                try? await UNUserNotificationCenter.current().add(makeRequest(
                    id: "\(Self.sustainPrefix)\(alarm.id.uuidString).\(index)",
                    alarmId: alarm.id,
                    sound: alarm.alarmSound.notificationSound,
                    title: "Wake-up mission",
                    body: "Tap to start your mission.",
                    tag: "sustain",
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                ))
            }
        }
    }

    private func makeRequest(
        id: String,
        alarmId: UUID,
        sound: UNNotificationSound,
        title: String,
        body: String,
        tag: String?,
        trigger: UNNotificationTrigger
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        var userInfo: [String: Any] = ["alarmId": alarmId.uuidString]
        if let tag { userInfo["wakeTag"] = tag }
        content.userInfo = userInfo
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private func cancelSustainBackups(for alarmId: UUID? = nil) async {
        let pending = await pendingRequests()
        let ids: [String]
        if let alarmId {
            let needle = "\(Self.sustainPrefix)\(alarmId.uuidString)."
            ids = pending.filter { $0.identifier.hasPrefix(needle) }.map(\.identifier)
        } else {
            ids = pending.filter { $0.identifier.hasPrefix(Self.sustainPrefix) }.map(\.identifier)
        }
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func cancelSnooze(for alarmId: UUID) async {
        await cancelRequests(withPrefix: "\(Self.primaryPrefix)snooze.\(alarmId.uuidString).")
    }

    private func cancelRequests(withPrefix prefix: String) async {
        let pending = await pendingRequests()
        let ids = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func isFollowUp(_ request: UNNotificationRequest, alarmId: UUID) -> Bool {
        let id = request.identifier
        let needle = alarmId.uuidString
        if id.hasPrefix("\(chaserPrefix)\(needle).") { return true }
        if id.hasPrefix("\(wakeChainPrefix)\(needle).") { return true }
        if id.hasPrefix("\(sustainPrefix)\(needle).") { return true }
        if id.hasPrefix("\(primaryPrefix)snooze.\(needle).") { return true }
        if id == "\(primaryPrefix)\(needle).once" { return true }
        if request.content.userInfo["wakeTag"] != nil { return true }
        return false
    }

    private func calendarWeekday(for weekday: Weekday) -> Int {
        switch weekday {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { continuation.resume(returning: $0) }
        }
    }

    private func deliveredNotifications() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getDeliveredNotifications { continuation.resume(returning: $0) }
        }
    }
}
#endif
