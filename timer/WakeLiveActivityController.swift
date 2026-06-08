#if os(iOS)
import ActivityKit
import Foundation
import WakeCore

/// Live Activity on lock screen / Dynamic Island while a wake mission is active.
enum WakeLiveActivityController {
    private actor Holder {
        var activity: Activity<WakeMissionAttributes>?

        func start(alarm: Alarm) async {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            await endAll()
            let timeLabel = String(format: "%02d:%02d", alarm.hour, alarm.minute)
            let attributes = WakeMissionAttributes(alarmTimeLabel: timeLabel)
            let state = WakeMissionAttributes.ContentState(missionTitle: alarm.missionType.title)
            do {
                activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: nil),
                    pushType: nil
                )
            } catch {
                activity = nil
            }
        }

        func endAll() async {
            if let activity {
                await activity.end(nil, dismissalPolicy: .immediate)
                self.activity = nil
            }
            for activity in Activity<WakeMissionAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static let holder = Holder()

    static func startIfAvailable(alarm: Alarm) {
        Task { await holder.start(alarm: alarm) }
    }

    /// Ends every `WakeMissionAttributes` activity (Dynamic Island / lock screen).
    static func endIfNeeded() {
        Task { await holder.endAll() }
    }

    static func endImmediately() async {
        await holder.endAll()
    }
}
#else
import Foundation

enum WakeLiveActivityController {
    static func startIfAvailable(alarm: Alarm) {}
    static func endIfNeeded() {}
    static func endImmediately() async {}
}
#endif
