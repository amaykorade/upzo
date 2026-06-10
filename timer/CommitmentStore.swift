#if os(iOS)
import Foundation

@MainActor
enum CommitmentStore {
    private static let completedKey = "commitment.hasCompleted"

    static var hasCompletedCommitment: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    static func markCompleted() {
        hasCompletedCommitment = true
        CloudKitUserDataSync.markLocalDataChanged()
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
}
#endif
