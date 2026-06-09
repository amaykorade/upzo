#if os(iOS)
import Combine
import Foundation

/// Stores the alarm ID requested by a tapped notification so the mission opens even when
/// the app launches cold (before SwiftUI views subscribe to `NotificationCenter`).
@MainActor
final class PendingMissionRouter: ObservableObject {
    static let shared = PendingMissionRouter()

    @Published private(set) var pendingAlarmID: UUID?

    private enum Keys {
        static let pendingAlarmID = "pendingMissionRouter.alarmID"
    }

    private init() {
        restoreFromDisk()
    }

    func setPending(_ id: UUID) {
        pendingAlarmID = id
        UserDefaults.standard.set(id.uuidString, forKey: Keys.pendingAlarmID)
    }

    func setPending(idString: String) {
        guard let id = UUID(uuidString: idString) else { return }
        setPending(id)
    }

    @discardableResult
    func consume() -> UUID? {
        let id = pendingAlarmID
        pendingAlarmID = nil
        UserDefaults.standard.removeObject(forKey: Keys.pendingAlarmID)
        return id
    }

    private func restoreFromDisk() {
        guard let idString = UserDefaults.standard.string(forKey: Keys.pendingAlarmID),
              let id = UUID(uuidString: idString)
        else { return }
        pendingAlarmID = id
    }
}
#endif
