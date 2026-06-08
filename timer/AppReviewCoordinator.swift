#if os(iOS)
import Foundation
import StoreKit
import UIKit

/// Requests the system App Store review dialog at natural success moments.
@MainActor
enum AppReviewCoordinator {
    private enum Keys {
        static let firstWakeAt = "appReview.firstWakeAt"
        static let lastPromptAt = "appReview.lastPromptAt"
        static let fulfilledMilestones = "appReview.fulfilledMilestones"
    }

    /// Call after a wake mission is completed — never on launch, sign-in, or paywall.
    static func considerPromptAfterSuccessfulWake(
        totalSuccessfulWakes: Int,
        streakDays: Int,
        now: Date = Date()
    ) {
        recordFirstWakeIfNeeded(now: now)

        let milestone = AppReviewEligibility.milestoneToRequest(
            totalSuccessfulWakes: totalSuccessfulWakes,
            streakDays: streakDays,
            now: now,
            firstWakeAt: firstWakeAt,
            lastPromptAt: lastPromptAt,
            fulfilledMilestoneIDs: fulfilledMilestoneIDs
        )
        guard let milestone else { return }

        // Brief delay so the mission dismiss animation finishes before the system sheet.
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            requestSystemReview()
            markMilestoneFulfilled(milestone, promptedAt: Date())
        }
    }

    static func requestSystemReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
        else { return }
        AppStore.requestReview(in: scene)
    }

    // MARK: - Persistence

    private static var defaults: UserDefaults { .standard }

    static var firstWakeAt: Date? {
        defaults.object(forKey: Keys.firstWakeAt) as? Date
    }

    static var lastPromptAt: Date? {
        defaults.object(forKey: Keys.lastPromptAt) as? Date
    }

    static var fulfilledMilestoneIDs: Set<String> {
        Set(defaults.stringArray(forKey: Keys.fulfilledMilestones) ?? [])
    }

    private static func recordFirstWakeIfNeeded(now: Date) {
        guard firstWakeAt == nil else { return }
        defaults.set(now, forKey: Keys.firstWakeAt)
    }

    private static func markMilestoneFulfilled(_ milestoneID: String, promptedAt: Date) {
        var ids = fulfilledMilestoneIDs
        ids.insert(milestoneID)
        defaults.set(Array(ids), forKey: Keys.fulfilledMilestones)
        defaults.set(promptedAt, forKey: Keys.lastPromptAt)
    }

    #if DEBUG
    static func resetForTesting() {
        defaults.removeObject(forKey: Keys.firstWakeAt)
        defaults.removeObject(forKey: Keys.lastPromptAt)
        defaults.removeObject(forKey: Keys.fulfilledMilestones)
    }
    #endif
}
#endif
