#if os(iOS)
import Combine
import Foundation

/// Persisted state for an in-progress wake cycle (ringing or mission still owed).
struct WakeSession: Codable, Equatable {
    enum Phase: String, Codable {
        /// AlarmKit is alerting; mission not finished yet.
        case ringing
        /// User stopped the alarm but has not completed the mission.
        case awaitingMission
    }

    var alarmId: UUID
    var phase: Phase
    var startedAt: Date
    var dismissedAt: Date?
    var expiresAt: Date
}

/// Disk-backed session for force-quit recovery. No scheduling logic.
@MainActor
final class WakeSessionStore: ObservableObject {
    static let shared = WakeSessionStore()

    @Published private(set) var session: WakeSession?

    var pendingMissionAlarmId: UUID? {
        guard let session, session.phase == .awaitingMission || session.phase == .ringing else { return nil }
        return session.alarmId
    }

    private enum Keys {
        static let session = "wake.session"
    }

    private init() {
        restore()
    }

    func beginRinging(alarmId: UUID, window: TimeInterval) {
        let now = Date()
        session = WakeSession(
            alarmId: alarmId,
            phase: .ringing,
            startedAt: now,
            dismissedAt: nil,
            expiresAt: now.addingTimeInterval(window)
        )
        persist()
    }

    func markAwaitingMission(alarmId: UUID, dismissedAt: Date, window: TimeInterval) {
        if var current = session, current.alarmId == alarmId {
            current.phase = .awaitingMission
            current.dismissedAt = dismissedAt
            current.expiresAt = dismissedAt.addingTimeInterval(window)
            session = current
        } else {
            session = WakeSession(
                alarmId: alarmId,
                phase: .awaitingMission,
                startedAt: dismissedAt,
                dismissedAt: dismissedAt,
                expiresAt: dismissedAt.addingTimeInterval(window)
            )
        }
        persist()
    }

    func clear() {
        session = nil
        UserDefaults.standard.removeObject(forKey: Keys.session)
    }

    func restoreIfNeeded() {
        if session == nil { restore() }
        if let session, Date() > session.expiresAt {
            clear()
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Keys.session),
              let decoded = try? JSONDecoder().decode(WakeSession.self, from: data),
              Date() < decoded.expiresAt
        else {
            clear()
            return
        }
        session = decoded
    }

    private func persist() {
        guard let session,
              let data = try? JSONEncoder().encode(session)
        else {
            clear()
            return
        }
        UserDefaults.standard.set(data, forKey: Keys.session)
    }
}
#endif
