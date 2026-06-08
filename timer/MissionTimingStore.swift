import Foundation

/// Tracks when a mission screen opens so we can measure response time on completion.
@MainActor
final class MissionTimingStore {
    static let shared = MissionTimingStore()

    private var beganAt: [UUID: Date] = [:]

    private init() {}

    func markMissionBegan(for alarmId: UUID, at date: Date = Date()) {
        beganAt[alarmId] = date
    }

    func clear(for alarmId: UUID) {
        beganAt.removeValue(forKey: alarmId)
    }

    /// Seconds from mission open to completion; nil if start was not recorded.
    func consumeResponseSeconds(for alarmId: UUID, completedAt: Date = Date()) -> Int? {
        guard let start = beganAt.removeValue(forKey: alarmId) else { return nil }
        return max(0, Int(completedAt.timeIntervalSince(start)))
    }
}
