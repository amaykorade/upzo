import XCTest
@testable import timer

// MARK: - Weekday & formatting

final class WeekdayAndFormattingTests: XCTestCase {
    func testWeekdayFromCalendarMapsCorrectly() {
        XCTAssertEqual(Weekday.fromCalendarWeekday(1), .sunday)
        XCTAssertEqual(Weekday.fromCalendarWeekday(2), .monday)
        XCTAssertEqual(Weekday.fromCalendarWeekday(7), .saturday)
        XCTAssertNil(Weekday.fromCalendarWeekday(0))
        XCTAssertNil(Weekday.fromCalendarWeekday(8))
    }

    func testSundayThroughSaturdayHasSevenDays() {
        XCTAssertEqual(Weekday.sundayThroughSaturday.count, 7)
        XCTAssertEqual(Weekday.sundayThroughSaturday.first, .sunday)
        XCTAssertEqual(Weekday.sundayThroughSaturday.last, .saturday)
    }

    func testRepeatSummaryLabels() {
        XCTAssertEqual(AlarmRowFormatting.repeatSummary(days: []), "No days")
        XCTAssertEqual(AlarmRowFormatting.repeatSummary(days: Weekday.allCases), "Every day")
        XCTAssertEqual(
            AlarmRowFormatting.repeatSummary(days: [.monday, .tuesday, .wednesday, .thursday, .friday]),
            "Weekdays"
        )
        XCTAssertEqual(AlarmRowFormatting.repeatSummary(days: [.saturday, .sunday]), "Weekends")
        XCTAssertTrue(AlarmRowFormatting.repeatSummary(days: [.monday, .wednesday]).contains("Mon"))
    }
}

// MARK: - Wake models & badges

final class WakeModelsTests: XCTestCase {
    func testWakeEventCodableRoundTrip() throws {
        let aid = UUID()
        let event = WakeEvent(
            alarmId: aid,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            missionType: .steps,
            responseSeconds: 90,
            alarmSound: .beacon
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(WakeEvent.self, from: data)
        XCTAssertEqual(decoded, event)
    }

    func testWakeBadgeCatalogFirstWakeAndStreak() {
        let badges = WakeBadgeCatalog.earned(streakDays: 7, totalWakes: 10, events: [])
        let ids = Set(badges.map(\.id))
        XCTAssertTrue(ids.contains("first_wake"))
        XCTAssertTrue(ids.contains("streak_3"))
        XCTAssertTrue(ids.contains("streak_7"))
        XCTAssertTrue(ids.contains("ten_wakes"))
        XCTAssertFalse(ids.contains("streak_30"))
    }

    func testWakeBadgeCatalogMissionProWhenAllTypesUsed() {
        let aid = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let events = MissionType.allCases.enumerated().map { index, mission in
            WakeEvent(
                alarmId: aid,
                completedAt: base.addingTimeInterval(TimeInterval(index)),
                missionType: mission,
                responseSeconds: 10,
                alarmSound: .classic
            )
        }
        let badges = WakeBadgeCatalog.earned(streakDays: 1, totalWakes: events.count, events: events)
        XCTAssertTrue(badges.contains { $0.id == "all_missions" })
    }
}

// MARK: - Alarm decode migration

final class AlarmDecodeTests: XCTestCase {
    func testDecodeScheduledAlarmWithEmptyRepeatDaysDefaultsToMonday() throws {
        let id = UUID()
        let jsonString = """
        {"id":"\(id.uuidString)","title":"","hour":7,"minute":30,"repeatDays":[],"scheduleMode":"scheduled","isEnabled":true,"missionType":"shake","alarmSound":"classic"}
        """
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let alarm = try JSONDecoder().decode(Alarm.self, from: data)
        XCTAssertEqual(alarm.repeatDays, [.monday])
        XCTAssertEqual(alarm.scheduleMode, .scheduled)
    }

    func testDecodeOneTimeLeavesEmptyRepeatDays() throws {
        let id = UUID()
        let jsonString = """
        {"id":"\(id.uuidString)","title":"","hour":12,"minute":0,"repeatDays":[],"scheduleMode":"oneTime","isEnabled":false,"missionType":"math","alarmSound":"pulse"}
        """
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let alarm = try JSONDecoder().decode(Alarm.self, from: data)
        XCTAssertTrue(alarm.repeatDays.isEmpty)
        XCTAssertEqual(alarm.scheduleMode, .oneTime)
        XCTAssertEqual(alarm.missionType, .math)
    }
}

// MARK: - OnboardingStore

final class OnboardingStoreTests: XCTestCase {
    @MainActor
    func testMarkCompletedClearsReturningUserSkip() {
        let store = OnboardingStore.shared
        store.resetForRetake()
        store.markSkippedForReturningUser()
        XCTAssertTrue(store.skippedOnboardingForReturningUser)
        store.markCompleted()
        XCTAssertFalse(store.skippedOnboardingForReturningUser)
    }

    @MainActor
    override func tearDown() {
        OnboardingStore.shared.resetForRetake()
        super.tearDown()
    }
}

// MARK: - WakeHistoryStore insights (main-actor isolated)

final class WakeHistoryInsightsTests: XCTestCase {
    func testMockStoreFavoriteMissionAndAverageResponse() {
        let done = expectation(description: "mainActor")
        Task { @MainActor in
            let store = WakeHistoryStore.mock()
            XCTAssertEqual(store.favoriteMission, .shake)
            XCTAssertEqual(store.averageResponseDisplay, "1m 16s")
            done.fulfill()
        }
        wait(for: [done], timeout: 2.0)
    }
}
