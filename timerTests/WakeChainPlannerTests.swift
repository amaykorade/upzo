#if os(iOS)
import XCTest
@testable import timer

final class WakeChainPlannerTests: XCTestCase {
    private let anchor = Date(timeIntervalSince1970: 1_000_000)

    func testFirstSystemRingFiresAtEightSeconds() {
        let first = WakeChainPlanner.systemRingDate(anchor: anchor, slot: 1)
        XCTAssertEqual(first.timeIntervalSince(anchor), WakeChainPlanner.firstRingDelay, accuracy: 0.001)
    }

    func testSecondSystemRingFiresThirtySecondsAfterFirst() {
        let first = WakeChainPlanner.systemRingDate(anchor: anchor, slot: 1)
        let second = WakeChainPlanner.systemRingDate(anchor: anchor, slot: 2)
        XCTAssertEqual(second.timeIntervalSince(first), WakeChainPlanner.ringInterval, accuracy: 0.001)
    }

    func testFirstNotificationPrecedesFirstRing() {
        let ring = WakeChainPlanner.systemRingDate(anchor: anchor, slot: 1)
        let notification = WakeChainPlanner.notificationDate(anchor: anchor, gapIndex: 0)
        XCTAssertEqual(ring.timeIntervalSince(notification), WakeChainPlanner.notificationLeadBeforeRing, accuracy: 0.001)
    }

    func testChainSlotIDsAreStable() {
        let source = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let slot1 = WakeChainPlanner.chainSlotID(for: source, slot: 1)
        let slot2 = WakeChainPlanner.chainSlotID(for: source, slot: 2)
        XCTAssertNotEqual(slot1, slot2)
        XCTAssertEqual(WakeChainPlanner.allChainSlotIDs(for: source).count, WakeChainPlanner.systemRingCount)
    }
}
#endif
