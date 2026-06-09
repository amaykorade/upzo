#if os(iOS)
import XCTest
@testable import timer

@MainActor
final class MissionOwedPersistenceTests: XCTestCase {
    private let sessionStore = WakeSessionStore.shared
    private let pendingRouter = PendingMissionRouter.shared
    private let recoveryStore = MissionRecoveryStore.shared

    override func setUp() {
        super.setUp()
        sessionStore.clear()
        pendingRouter.consume()
        recoveryStore.clear()
        UserDefaults.standard.removeObject(forKey: "pendingMissionRouter.alarmID")
    }

    override func tearDown() {
        sessionStore.clear()
        pendingRouter.consume()
        recoveryStore.clear()
        UserDefaults.standard.removeObject(forKey: "pendingMissionRouter.alarmID")
        super.tearDown()
    }

    func testRecordMissionOwedPersistsAcrossStores() {
        let alarm = Alarm(hour: 7, minute: 0, missionType: .shake)
        WakeDeliveryService.recordMissionOwed(alarm: alarm)

        XCTAssertEqual(sessionStore.pendingMissionAlarmId, alarm.id)
        XCTAssertEqual(pendingRouter.pendingAlarmID, alarm.id)
        XCTAssertEqual(recoveryStore.pendingMissionAlarmID, alarm.id)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "pendingMissionRouter.alarmID"),
            alarm.id.uuidString
        )
    }

    func testPendingRouterPersistsToUserDefaults() {
        let alarmId = UUID()
        pendingRouter.setPending(alarmId)
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "pendingMissionRouter.alarmID"),
            alarmId.uuidString
        )
    }
}
#endif
