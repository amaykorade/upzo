import ActivityKit
import Foundation

/// Shared by the app (start/end) and the widget extension (presentation). Keep fields stable for ActivityKit.
public struct WakeMissionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var missionTitle: String

        public init(missionTitle: String) {
            self.missionTitle = missionTitle
        }
    }

    public var alarmTimeLabel: String

    public init(alarmTimeLabel: String) {
        self.alarmTimeLabel = alarmTimeLabel
    }
}
