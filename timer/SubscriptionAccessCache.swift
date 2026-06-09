#if os(iOS)
import Foundation

/// Remembers the paid-through date so cancelled subscriptions stay unlocked until the period ends.
enum SubscriptionAccessCache {
    private static let accessUntilKey = "subscription.accessUntil"

    static var accessUntil: Date? {
        let interval = UserDefaults.standard.double(forKey: accessUntilKey)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static var hasValidAccess: Bool {
        guard let until = accessUntil else { return false }
        return until > Date()
    }

    static func save(accessUntil date: Date) {
        guard date > Date() else { return }
        if let existing = accessUntil {
            UserDefaults.standard.set(max(existing, date).timeIntervalSince1970, forKey: accessUntilKey)
        } else {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: accessUntilKey)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: accessUntilKey)
    }
}
#endif
