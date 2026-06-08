#if os(iOS)
import XCTest
@testable import timer

@MainActor
final class WakeSessionStoreTests: XCTestCase {
    private let store = WakeSessionStore.shared
    private let alertSessions = AlarmAlertSessionStore.shared

    override func setUp() {
        super.setUp()
        store.clear()
    }

    override func tearDown() {
        store.clear()
        super.tearDown()
    }

    func testMarkAwaitingMissionBootstrapsSessionWhenNil() {
        let alarmId = UUID()
        let dismissedAt = Date()
        let window: TimeInterval = 600

        store.markAwaitingMission(alarmId: alarmId, dismissedAt: dismissedAt, window: window)

        XCTAssertEqual(store.session?.alarmId, alarmId)
        XCTAssertEqual(store.session?.phase, .awaitingMission)
        XCTAssertEqual(store.session?.dismissedAt, dismissedAt)
        XCTAssertEqual(store.pendingMissionAlarmId, alarmId)
    }

    func testMarkAwaitingMissionUpdatesExistingRingingSession() {
        let alarmId = UUID()
        store.beginRinging(alarmId: alarmId, window: 600)

        let dismissedAt = Date()
        store.markAwaitingMission(alarmId: alarmId, dismissedAt: dismissedAt, window: 600)

        XCTAssertEqual(store.session?.phase, .awaitingMission)
        XCTAssertEqual(store.session?.dismissedAt, dismissedAt)
        XCTAssertEqual(store.session?.startedAt, store.session?.startedAt)
    }

    func testAlertSessionSuppressionIsPerCycle() {
        let alarmId = UUID()

        alertSessions.beginNewAlertCycle(alarmId: alarmId)
        XCTAssertFalse(alertSessions.shouldSuppressFollowUpNotification(alarmId: alarmId))

        alertSessions.markMissionCompleted(alarmId: alarmId)
        XCTAssertTrue(alertSessions.shouldSuppressFollowUpNotification(alarmId: alarmId))

        alertSessions.beginNewAlertCycle(alarmId: alarmId)
        XCTAssertFalse(alertSessions.shouldSuppressFollowUpNotification(alarmId: alarmId))
    }
}
#endif
