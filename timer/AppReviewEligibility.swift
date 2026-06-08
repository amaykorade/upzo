#if os(iOS)
import Foundation

/// Rules for when Upzo may ask for an App Store review (Apple HIG: positive moment, not on launch).
enum AppReviewEligibility {
    static let wakeCountMilestones = [3, 10, 25]
    static let streakDayMilestone = 7
    static let minimumDaysSinceFirstWake = 2
    static let promptCooldownDays = 120

    /// Returns a milestone id when the system review dialog may be shown, else nil.
    static func milestoneToRequest(
        totalSuccessfulWakes: Int,
        streakDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current,
        firstWakeAt: Date?,
        lastPromptAt: Date?,
        fulfilledMilestoneIDs: Set<String>
    ) -> String? {
        guard totalSuccessfulWakes >= wakeCountMilestones[0] else { return nil }
        guard let firstWakeAt else { return nil }

        let daysSinceFirstWake = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: firstWakeAt),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        guard daysSinceFirstWake >= minimumDaysSinceFirstWake else { return nil }

        if let lastPromptAt {
            let daysSinceLastPrompt = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastPromptAt),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            guard daysSinceLastPrompt >= promptCooldownDays else { return nil }
        }

        if wakeCountMilestones.contains(totalSuccessfulWakes) {
            let id = wakeMilestoneID(count: totalSuccessfulWakes)
            if !fulfilledMilestoneIDs.contains(id) { return id }
        }

        if streakDays == streakDayMilestone {
            let id = streakMilestoneID
            if !fulfilledMilestoneIDs.contains(id) { return id }
        }

        return nil
    }

    static func wakeMilestoneID(count: Int) -> String {
        "wake_\(count)"
    }

    static var streakMilestoneID: String { "streak_\(streakDayMilestone)" }
}
#endif
