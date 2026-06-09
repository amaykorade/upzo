import XCTest
@testable import timer

final class SubscriptionAccessCacheTests: XCTestCase {
    override func tearDown() {
        SubscriptionAccessCache.clear()
        super.tearDown()
    }

    func testValidAccessBeforeExpiration() {
        let until = Date().addingTimeInterval(60 * 60 * 24 * 7)
        SubscriptionAccessCache.save(accessUntil: until)
        XCTAssertTrue(SubscriptionAccessCache.hasValidAccess)
    }

    func testInvalidAccessAfterExpiration() {
        UserDefaults.standard.set(
            Date().addingTimeInterval(-3600).timeIntervalSince1970,
            forKey: "subscription.accessUntil"
        )
        XCTAssertFalse(SubscriptionAccessCache.hasValidAccess)
    }

    func testKeepsLatestExpiration() {
        let sooner = Date().addingTimeInterval(60 * 60 * 24)
        let later = Date().addingTimeInterval(60 * 60 * 24 * 30)
        SubscriptionAccessCache.save(accessUntil: sooner)
        SubscriptionAccessCache.save(accessUntil: later)
        XCTAssertEqual(
            SubscriptionAccessCache.accessUntil?.timeIntervalSince1970 ?? 0,
            later.timeIntervalSince1970,
            accuracy: 1
        )
    }
}
