#if os(iOS)
import Combine
import Foundation

/// Stores the alarm ID requested by a tapped notification so the mission opens even when
/// the app launches cold (before SwiftUI views subscribe to `NotificationCenter`).
@MainActor
final class PendingMissionRouter: ObservableObject {
    static let shared = PendingMissionRouter()

    @Published private(set) var pendingAlarmID: UUID?

    private init() {}

    func setPending(_ id: UUID) {
        pendingAlarmID = id
    }

    func setPending(idString: String) {
        guard let id = UUID(uuidString: idString) else { return }
        setPending(id)
    }

    @discardableResult
    func consume() -> UUID? {
        let id = pendingAlarmID
        pendingAlarmID = nil
        return id
    }
}
#endif
