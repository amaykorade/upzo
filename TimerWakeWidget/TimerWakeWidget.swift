import ActivityKit
import AlarmKit
import SwiftUI
import WakeCore
import WidgetKit

@main
struct TimerWakeWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpzoAlarmLiveActivity()
        WakeMissionLiveActivityWidget()
    }
}

/// Required by AlarmKit for countdown / alert presentations. Without this, alarms may dismiss without running stop intents.
struct UpzoAlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<TimerWakeAlarmMetadata>.self) { context in
            UpzoAlarmLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text("Time to wake up")
                        .font(.headline)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                Image(systemName: "sun.max.fill")
            } minimal: {
                Image(systemName: "alarm.fill")
            }
        }
    }
}

private struct UpzoAlarmLockScreenView: View {
    let context: ActivityViewContext<AlarmAttributes<TimerWakeAlarmMetadata>>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Time to wake up", systemImage: "alarm.fill")
                .font(.headline)
            Text("Open Upzo to finish your wake-up mission.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct WakeMissionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WakeMissionAttributes.self) { context in
            VStack(alignment: .leading, spacing: 6) {
                Label("Wake-up mission", systemImage: "alarm.fill")
                    .font(.headline)
                Text(context.state.missionTitle)
                    .font(.subheadline.weight(.semibold))
                Text("Alarm \(context.attributes.alarmTimeLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text("Finish your mission")
                            .font(.caption.weight(.semibold))
                        Text(context.state.missionTitle)
                            .font(.footnote)
                    }
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                Text(context.attributes.alarmTimeLabel)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "alarm")
            }
        }
    }
}
