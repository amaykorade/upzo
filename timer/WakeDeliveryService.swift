#if os(iOS)
import AlarmKit
import AVFoundation
import Combine
import Foundation
import UIKit

/// Single entry point for alarm delivery: AlarmKit wake chain, notification-only fallback, session state.
@MainActor
final class WakeDeliveryService: ObservableObject {
    static let shared = WakeDeliveryService()

    private let sessionStore = WakeSessionStore.shared
    private let notifications = AlarmNotificationManager.shared
    private let backgroundAudio = WakeBackgroundAudioPlayer()

    static let catchupWindow: TimeInterval = 10 * 60

    private init() {}

    var pendingMissionAlarmId: UUID? { sessionStore.pendingMissionAlarmId }

    /// Called from `OpenWakeMissionIntent` when the user stops a system AlarmKit alert.
    @MainActor
    static func registerMissionOwedFromSystemAlarmTap(kitAlarmIDString: String) {
        guard let kitId = UUID(uuidString: kitAlarmIDString) else { return }
        let sourceID = AlarmKitAlarmService.sourceAlarmID(for: kitId)
        guard let alarm = AlarmStore.alarmFromDisk(id: sourceID), alarm.isEnabled else { return }

        AlarmAlertSessionStore.shared.beginNewAlertCycle(alarmId: sourceID)
        let store = WakeSessionStore.shared
        store.restoreIfNeeded()
        store.markAwaitingMission(
            alarmId: sourceID,
            dismissedAt: Date(),
            window: catchupWindow
        )
        PendingMissionRouter.shared.setPending(sourceID)
        NotificationCenter.default.post(
            name: .timerOpenMissionAlarm,
            object: nil,
            userInfo: ["alarmId": sourceID.uuidString]
        )
        Task { @MainActor in
            await WakeDeliveryService.shared.scheduleFollowUpsAfterDismiss(alarm: alarm)
        }
    }

    // MARK: - Alarm list sync

    func syncAllAlarms(_ alarms: [Alarm]) async {
        await AlarmKitAlarmService.syncIfPossible(alarms: alarms)
        if AlarmKitAlarmService.shouldUseNotificationFallback {
            await notifications.schedulePrimaryAlarms(alarms)
        } else {
            await notifications.cancelPrimaryAlarms()
        }
    }

    // MARK: - Lifecycle

    func appBecameActive(
        wakeHistory: WakeHistoryStore? = nil,
        alarmStore: AlarmStore? = nil
    ) async {
        sessionStore.restoreIfNeeded()
        if let wakeHistory, let alarmStore {
            _ = await reconcileAlarmKitOnBecomeActive(
                wakeHistory: wakeHistory,
                alarmStore: alarmStore
            )
        }
        await ensureWakeChainIfNeeded()
    }

    /// Polls AlarmKit after a cold start or missed stream transition; returns an alarm id that should present a mission.
    func reconcileAlarmKitOnBecomeActive(
        wakeHistory: WakeHistoryStore,
        alarmStore: AlarmStore
    ) async -> UUID? {
        sessionStore.restoreIfNeeded()
        guard AlarmKitAlarmService.isAuthorized else {
            return sessionStore.pendingMissionAlarmId ?? PendingMissionRouter.shared.pendingAlarmID
        }

        guard let kits = try? AlarmManager.shared.alarms else {
            return sessionStore.pendingMissionAlarmId ?? PendingMissionRouter.shared.pendingAlarmID
        }

        for kit in kits {
            let sourceID = AlarmKitAlarmService.sourceAlarmID(for: kit.id)
            guard let alarm = alarmStore.alarm(id: sourceID), alarm.isEnabled else { continue }

            let cycleStart = AlarmAlertSessionStore.shared.cycleBeganAt(for: sourceID)
                ?? sessionStore.session?.startedAt
                ?? Date().addingTimeInterval(-Self.catchupWindow)

            if wakeHistory.hasCompletion(forAlarmId: sourceID, onOrAfter: cycleStart) { continue }
            if AlarmAlertSessionStore.shared.shouldSuppressFollowUpNotification(alarmId: sourceID) { continue }

            switch kit.state {
            case .alerting:
                if sessionStore.session?.alarmId != sourceID || sessionStore.session?.phase != .ringing {
                    AlarmAlertSessionStore.shared.beginNewAlertCycle(alarmId: sourceID)
                    sessionStore.beginRinging(alarmId: sourceID, window: Self.catchupWindow)
                }
                if UIApplication.shared.applicationState == .active {
                    backgroundAudio.start(alarm: alarm)
                }
                let anchor = sessionStore.session?.startedAt ?? Date()
                await armWakeChain(for: alarm, anchor: anchor)
                return sourceID

            case .countdown:
                sessionStore.markAwaitingMission(
                    alarmId: sourceID,
                    dismissedAt: Date(),
                    window: Self.catchupWindow
                )
                return sourceID

            case .scheduled, .paused:
                break
            }
        }

        return sessionStore.pendingMissionAlarmId ?? PendingMissionRouter.shared.pendingAlarmID
    }

    func appEnteredBackground(alarmStore: AlarmStore) async {
        sessionStore.restoreIfNeeded()
        await ensureWakeChainIfNeeded()
        // Alarm audio while backgrounded is handled by AlarmKit / notifications, not UIBackgroundModes audio.
    }

    func missionPresentationBegan(for alarm: Alarm) {
        backgroundAudio.stop()
        AlarmKitAlarmService.stopActiveAlerting(for: alarm.id)
    }

    func missionUIClosedWithoutCompletion(alarmId: UUID) async {
        sessionStore.restoreIfNeeded()
        guard let session = sessionStore.session,
              session.alarmId == alarmId,
              session.phase == .awaitingMission,
              let alarm = AlarmStore.alarmFromDisk(id: alarmId),
              alarm.isEnabled,
              !AlarmAlertSessionStore.shared.shouldSuppressFollowUpNotification(alarmId: alarmId)
        else { return }
        await scheduleFollowUpsAfterDismiss(alarm: alarm)
    }

    func missionCompleted(alarmId: UUID) async {
        backgroundAudio.stop()
        await WakeLiveActivityController.endImmediately()
        AlarmKitAlarmService.cancelWakeChain(for: alarmId)
        await notifications.cancelFollowUps(for: alarmId)
        await notifications.clearDeliveredWakeAlerts(for: alarmId)
        await AlarmKitAlarmService.restoreRepeatingSchedule(alarmId: alarmId)
        sessionStore.clear()
    }

    func notificationDismissedWithoutMission(alarmId: UUID) async {
        guard let alarm = AlarmStore.alarmFromDisk(id: alarmId), alarm.isEnabled else { return }
        guard !AlarmAlertSessionStore.shared.shouldSuppressFollowUpNotification(alarmId: alarmId) else { return }
        await userStoppedAlarmWithoutMission(alarm: alarm)
    }

    // MARK: - AlarmKit stream

    func processAlarmKitUpdate(
        _ kits: [AlarmKit.Alarm],
        wakeHistory: WakeHistoryStore,
        alarmStore: AlarmStore
    ) async {
        sessionStore.restoreIfNeeded()
        await expireSessionIfNeeded()

        let idsInBatch = Set(kits.map { AlarmKitAlarmService.sourceAlarmID(for: $0.id) })
        var previousStates = alarmKitStateCache
        alarmKitStateCache = [:]

        for id in previousStates.keys where !idsInBatch.contains(id) {
            if previousStates[id] == .alerting {
                await alarmKitStoppedAlerting(alarmId: id, wakeHistory: wakeHistory, alarmStore: alarmStore)
            }
        }

        for kit in kits {
            let id = AlarmKitAlarmService.sourceAlarmID(for: kit.id)
            let was = previousStates[id]
            alarmKitStateCache[id] = kit.state

            if kit.state == .alerting, was != .alerting {
                AlarmAlertSessionStore.shared.beginNewAlertCycle(alarmId: id)
                guard let alarm = alarmStore.alarm(id: id) else { continue }
                await alarmKitStartedAlerting(alarm: alarm)
            } else if kit.state != .alerting, was == .alerting {
                await alarmKitStoppedAlerting(alarmId: id, wakeHistory: wakeHistory, alarmStore: alarmStore)
            }
        }
    }

    private var alarmKitStateCache: [UUID: AlarmKit.Alarm.State] = [:]

    // MARK: - Private

    private func alarmKitStartedAlerting(alarm: Alarm) async {
        guard !AlarmAlertSessionStore.shared.shouldSuppressFollowUpNotification(alarmId: alarm.id) else { return }
        let anchor = Date()
        sessionStore.beginRinging(alarmId: alarm.id, window: Self.catchupWindow)
        // In-app alarm loop only while foreground; system AlarmKit continues when backgrounded.
        if UIApplication.shared.applicationState == .active {
            backgroundAudio.start(alarm: alarm)
        }
        await armWakeChain(for: alarm, anchor: anchor)
    }

    private func alarmKitStoppedAlerting(
        alarmId: UUID,
        wakeHistory: WakeHistoryStore,
        alarmStore: AlarmStore
    ) async {
        guard let alarm = alarmStore.alarm(id: alarmId), alarm.isEnabled else {
            await cancelWakeChain(for: alarmId)
            return
        }

        let began = sessionStore.session?.startedAt ?? Date().addingTimeInterval(-1)
        if wakeHistory.hasCompletion(forAlarmId: alarmId, onOrAfter: began)
            || AlarmAlertSessionStore.shared.shouldSuppressFollowUpNotification(alarmId: alarmId) {
            await missionCompleted(alarmId: alarmId)
            return
        }

        await userStoppedAlarmWithoutMission(alarm: alarm)
    }

    private func userStoppedAlarmWithoutMission(alarm: Alarm) async {
        backgroundAudio.stop()
        sessionStore.markAwaitingMission(alarmId: alarm.id, dismissedAt: Date(), window: Self.catchupWindow)
        await scheduleFollowUpsAfterDismiss(alarm: alarm)
    }

    func scheduleFollowUpsAfterDismiss(alarm: Alarm) async {
        let anchor = Date()
        await armWakeChain(for: alarm, anchor: anchor)
        await notifications.scheduleDismissChasers(for: alarm)
    }

    private func armWakeChain(for alarm: Alarm, anchor: Date) async {
        guard AlarmKitAlarmService.isAuthorized else { return }
        _ = await AlarmKitAlarmService.scheduleWakeChain(for: alarm, from: anchor)
        await notifications.scheduleWakeChain(for: alarm, from: anchor)
    }

    private func cancelWakeChain(for alarmId: UUID) async {
        AlarmKitAlarmService.cancelWakeChain(for: alarmId)
        await notifications.cancelWakeChain(for: alarmId)
    }

    private func ensureWakeChainIfNeeded() async {
        guard let wakeSession = sessionStore.session,
              Date() < wakeSession.expiresAt,
              let alarm = AlarmStore.alarmFromDisk(id: wakeSession.alarmId),
              alarm.isEnabled,
              !AlarmAlertSessionStore.shared.shouldSuppressFollowUpNotification(alarmId: alarm.id)
        else {
            if let id = sessionStore.session?.alarmId {
                await missionCompleted(alarmId: id)
            }
            return
        }

        let kitScheduled = AlarmKitAlarmService.hasWakeChainScheduled(for: alarm.id)
        let notifScheduled = await notifications.hasWakeChain(for: alarm.id)
        if kitScheduled && notifScheduled {
            return
        }
        await armWakeChain(for: alarm, anchor: wakeChainAnchor(for: wakeSession))
    }

    private func wakeChainAnchor(for session: WakeSession) -> Date {
        let base = max(session.startedAt, session.dismissedAt ?? session.startedAt)
        let firstFire = WakeChainPlanner.systemRingDate(anchor: base, slot: 1)
        if firstFire > Date() {
            return base
        }
        return Date()
    }

    private func expireSessionIfNeeded() async {
        guard let wakeSession = sessionStore.session, Date() > wakeSession.expiresAt else { return }
        await missionCompleted(alarmId: wakeSession.alarmId)
    }

    private func activeAlarm(from alarmStore: AlarmStore) -> Alarm? {
        guard let id = sessionStore.pendingMissionAlarmId else { return nil }
        return alarmStore.alarm(id: id)
    }
}

// MARK: - Background audio (while app is open / backgrounded, not after force-quit)

@MainActor
private final class WakeBackgroundAudioPlayer {
    private var player: AVAudioPlayer?
    private var activeAlarmId: UUID?

    func start(alarm: Alarm) {
        guard activeAlarmId != alarm.id else { return }
        stop()

        activeAlarmId = alarm.id
        let session = AVAudioSession.sharedInstance()
        guard (try? session.setCategory(.playback, mode: .default, options: [.duckOthers])) != nil,
              (try? session.setActive(true)) != nil
        else { return }

        let url = alarm.alarmSound.bundleURL
            ?? Bundle.main.url(forResource: "mission_alarm", withExtension: "wav")
        guard let url, let p = try? AVAudioPlayer(contentsOf: url), p.play() else { return }
        p.numberOfLoops = -1
        p.volume = 1.0
        player = p
    }

    func stop() {
        activeAlarmId = nil
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
#endif
