import ActivityKit
import SwiftUI
import WakeCore
import WidgetKit

@main
struct TimerWakeWidgetBundle: WidgetBundle {
    var body: some Widget {
        WakeMissionLiveActivityWidget()
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
