import XCTest
@testable import timer

final class PushupReadyLatchTests: XCTestCase {
    func testInactiveByDefault() {
        var latch = PushupReadyLatch()
        XCTAssertFalse(latch.isActive())
    }

    func testActivatesWhenReady() {
        var latch = PushupReadyLatch()
        let now = Date(timeIntervalSince1970: 1_000)
        latch.refreshIfReady(true, now: now)
        XCTAssertTrue(latch.isActive(now: now))
    }

    func testDoesNotActivateWhenNotReady() {
        var latch = PushupReadyLatch()
        latch.refreshIfReady(false)
        XCTAssertFalse(latch.isActive())
    }

    func testExpiresAfterLatchDuration() {
        var latch = PushupReadyLatch()
        let start = Date(timeIntervalSince1970: 1_000)
        latch.refreshIfReady(true, now: start)
        XCTAssertTrue(latch.isActive(now: start))

        let afterExpiry = start.addingTimeInterval(PushupReadyLatch.latchDuration + 0.1)
        XCTAssertFalse(latch.isActive(now: afterExpiry))
    }

    func testRefreshExtendsLatch() {
        var latch = PushupReadyLatch()
        let t0 = Date(timeIntervalSince1970: 1_000)
        latch.refreshIfReady(true, now: t0)

        let t5 = t0.addingTimeInterval(5)
        latch.refreshIfReady(true, now: t5)

        let t12 = t0.addingTimeInterval(12)
        XCTAssertTrue(latch.isActive(now: t12))
    }

    func testClearResetsLatch() {
        var latch = PushupReadyLatch()
        latch.refreshIfReady(true)
        latch.clear()
        XCTAssertFalse(latch.isActive())
    }
}
