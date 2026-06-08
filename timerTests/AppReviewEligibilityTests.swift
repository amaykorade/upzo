import XCTest
@testable import timer

#if os(iOS)
final class AppReviewEligibilityTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
        now = cal.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 8))!
    }

    func testNoPromptBeforeThirdWake() {
        let firstWake = calendar.date(byAdding: .day, value: -5, to: now)!
        XCTAssertNil(
            AppReviewEligibility.milestoneToRequest(
                totalSuccessfulWakes: 2,
                streakDays: 2,
                now: now,
                calendar: calendar,
                firstWakeAt: firstWake,
                lastPromptAt: nil,
                fulfilledMilestoneIDs: []
            )
        )
    }

    func testNoPromptWithinMinimumDaysSinceFirstWake() {
        let firstWake = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertNil(
            AppReviewEligibility.milestoneToRequest(
                totalSuccessfulWakes: 3,
                streakDays: 3,
                now: now,
                calendar: calendar,
                firstWakeAt: firstWake,
                lastPromptAt: nil,
                fulfilledMilestoneIDs: []
            )
        )
    }

    func testPromptOnThirdWakeAfterMinimumDays() {
        let firstWake = calendar.date(byAdding: .day, value: -3, to: now)!
        XCTAssertEqual(
            AppReviewEligibility.milestoneToRequest(
                totalSuccessfulWakes: 3,
                streakDays: 3,
                now: now,
                calendar: calendar,
                firstWakeAt: firstWake,
                lastPromptAt: nil,
                fulfilledMilestoneIDs: []
            ),
            AppReviewEligibility.wakeMilestoneID(count: 3)
        )
    }

    func testPromptOnSevenDayStreakMilestone() {
        let firstWake = calendar.date(byAdding: .day, value: -10, to: now)!
        XCTAssertEqual(
            AppReviewEligibility.milestoneToRequest(
                totalSuccessfulWakes: 5,
                streakDays: 7,
                now: now,
                calendar: calendar,
                firstWakeAt: firstWake,
                lastPromptAt: nil,
                fulfilledMilestoneIDs: []
            ),
            AppReviewEligibility.streakMilestoneID
        )
    }

    func testRespectsCooldownAfterPreviousPrompt() {
        let firstWake = calendar.date(byAdding: .day, value: -30, to: now)!
        let lastPrompt = calendar.date(byAdding: .day, value: -10, to: now)!
        XCTAssertNil(
            AppReviewEligibility.milestoneToRequest(
                totalSuccessfulWakes: 10,
                streakDays: 10,
                now: now,
                calendar: calendar,
                firstWakeAt: firstWake,
                lastPromptAt: lastPrompt,
                fulfilledMilestoneIDs: [AppReviewEligibility.wakeMilestoneID(count: 3)]
            )
        )
    }

    func testSkipsAlreadyFulfilledMilestone() {
        let firstWake = calendar.date(byAdding: .day, value: -5, to: now)!
        XCTAssertNil(
            AppReviewEligibility.milestoneToRequest(
                totalSuccessfulWakes: 3,
                streakDays: 3,
                now: now,
                calendar: calendar,
                firstWakeAt: firstWake,
                lastPromptAt: nil,
                fulfilledMilestoneIDs: [AppReviewEligibility.wakeMilestoneID(count: 3)]
            )
        )
    }
}
#endif
