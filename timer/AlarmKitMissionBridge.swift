#if os(iOS)
import AlarmKit
import Combine
import SwiftUI
import UIKit

/// Short pulses while any AlarmKit alarm is alerting — still noticeable if ring volume is low.
private final class AlertingHapticPulse: ObservableObject {
    private var timer: Timer?

    func setAlertingActive(_ active: Bool) {
        timer?.invalidate()
        timer = nil
        guard active else { return }

        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        impact.impactOccurred(intensity: 1.0)

        var tick = 0
        let t = Timer(timeInterval: 1.8, repeats: true) { _ in
            tick += 1
            impact.impactOccurred(intensity: 1.0)
            if tick % 3 == 0 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }
}

/// Presents the mission when AlarmKit alerts and forwards lifecycle events to `WakeDeliveryService`.
struct AlarmKitMissionBridgeModifier: ViewModifier {
    @EnvironmentObject private var alarmStore: AlarmStore
    @EnvironmentObject private var wakeHistory: WakeHistoryStore
    @Binding var missionAlarm: Alarm?

    @StateObject private var alertingHaptics = AlertingHapticPulse()
    @ObservedObject private var wakeSession = WakeSessionStore.shared

    private let delivery = WakeDeliveryService.shared

    func body(content: Content) -> some View {
        content
            .task {
                for await batch in AlarmManager.shared.alarmUpdates {
                    let anyAlerting = batch.contains { $0.state == .alerting }
                    alertingHaptics.setAlertingActive(anyAlerting)
                    await delivery.processAlarmKitUpdate(batch, wakeHistory: wakeHistory, alarmStore: alarmStore)
                    presentMissionIfAlerting(in: batch)
                }
            }
            .onChange(of: wakeSession.session) { _, _ in
                presentCatchupIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                Task {
                    if let id = await delivery.reconcileAlarmKitOnBecomeActive(
                        wakeHistory: wakeHistory,
                        alarmStore: alarmStore
                    ),
                       let alarm = alarmStore.alarm(id: id) {
                        await MainActor.run {
                            if missionAlarm == nil {
                                missionAlarm = alarm
                            }
                        }
                    }
                    presentCatchupIfNeeded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                Task { await delivery.appEnteredBackground(alarmStore: alarmStore) }
            }
    }

    private func presentMissionIfAlerting(in batch: [AlarmKit.Alarm]) {
        for kit in batch where kit.state == .alerting {
            let sourceID = AlarmKitAlarmService.sourceAlarmID(for: kit.id)
            guard let alarm = alarmStore.alarm(id: sourceID) else { continue }
            if missionAlarm?.id != alarm.id {
                missionAlarm = alarm
            }
        }
    }

    private func presentCatchupIfNeeded() {
        guard missionAlarm == nil else { return }

        if let id = PendingMissionRouter.shared.pendingAlarmID,
           let alarm = alarmStore.alarm(id: id) {
            missionAlarm = alarm
            PendingMissionRouter.shared.consume()
            return
        }

        guard let id = wakeSession.pendingMissionAlarmId,
              let alarm = alarmStore.alarm(id: id)
        else { return }
        missionAlarm = alarm
    }
}

extension View {
    func alarmKitMissionBridge(missionAlarm: Binding<Alarm?>) -> some View {
        modifier(AlarmKitMissionBridgeModifier(missionAlarm: missionAlarm))
    }
}
#endif
