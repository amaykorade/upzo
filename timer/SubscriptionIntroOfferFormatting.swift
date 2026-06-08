#if os(iOS)
import Foundation
import StoreKit

enum SubscriptionIntroOfferFormatting {
    static func periodDescription(_ period: Product.SubscriptionPeriod) -> String {
        let count = period.value
        let unitLabel: String
        switch period.unit {
        case .day: unitLabel = count == 1 ? "day" : "days"
        case .week: unitLabel = count == 1 ? "week" : "weeks"
        case .month: unitLabel = count == 1 ? "month" : "months"
        case .year: unitLabel = count == 1 ? "year" : "years"
        @unknown default: unitLabel = "period"
        }
        return count == 1 ? "1 \(unitLabel)" : "\(count) \(unitLabel)"
    }

    static func renewalCadence(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .month: return "month"
        case .year: return "year"
        case .week: return "week"
        case .day: return "day"
        @unknown default: return "period"
        }
    }

    /// e.g. "3 days free, then $9.99/month"
    static func freeTrialPlanSubtitle(
        introPeriod: Product.SubscriptionPeriod,
        price: String,
        renewalPeriod: Product.SubscriptionPeriod
    ) -> String {
        "\(periodDescription(introPeriod)) free, then \(price)/\(renewalCadence(renewalPeriod))"
    }

    /// e.g. "$9.99/month" — primary billed amount label for paywall (most conspicuous).
    static func billedAmountLabel(price: String, renewalPeriod: Product.SubscriptionPeriod) -> String {
        "\(price)/\(renewalCadence(renewalPeriod))"
    }

    /// Small subordinate copy when a free trial may apply (must be smaller/less prominent than billed amount).
    static func trialSubordinateNote(introPeriod: Product.SubscriptionPeriod) -> String {
        "\(periodDescription(introPeriod)) free trial for eligible new subscribers"
    }

    static func freeTrialHeadline(introPeriod: Product.SubscriptionPeriod) -> String {
        "Start your \(periodDescription(introPeriod)) free trial"
    }

    static func paywallTrialDisclaimer(introPeriod: Product.SubscriptionPeriod) -> String {
        let trial = periodDescription(introPeriod)
        return """
        After your \(trial) free trial, your subscription renews automatically unless you cancel at least 24 hours before the trial ends. Manage or cancel in Settings → Apple ID → Subscriptions.
        """
    }
}
#endif
