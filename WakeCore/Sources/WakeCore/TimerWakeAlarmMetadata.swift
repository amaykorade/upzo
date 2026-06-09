#if canImport(AlarmKit)
import AlarmKit
import Foundation

/// Shared metadata for AlarmKit scheduling and the widget Live Activity.
public struct TimerWakeAlarmMetadata: AlarmMetadata, Codable, Hashable, Sendable {}
#endif
