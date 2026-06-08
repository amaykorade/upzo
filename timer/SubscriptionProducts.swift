import Foundation

/// Product identifiers — must match App Store Connect → Subscriptions exactly.
enum SubscriptionProducts {
    /// Auto-renewable monthly ($9.99/month in App Store Connect).
    static let monthly = "com.amay.timer.plus.monthly"
    /// Auto-renewable yearly ($29.99/year in App Store Connect).
    static let yearly = "com.amay.timer.plus.yearly"

    static var all: [String] { [monthly, yearly] }
}
