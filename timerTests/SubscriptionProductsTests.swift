import XCTest
@testable import timer

final class SubscriptionProductsTests: XCTestCase {
    func testProductIDsAreStable() {
        XCTAssertEqual(SubscriptionProducts.monthly, "com.amay.timer.plus.monthly")
        XCTAssertEqual(SubscriptionProducts.yearly, "com.amay.timer.plus.yearly")
        XCTAssertEqual(SubscriptionProducts.all.count, 2)
        XCTAssertTrue(SubscriptionProducts.all.contains(SubscriptionProducts.monthly))
        XCTAssertTrue(SubscriptionProducts.all.contains(SubscriptionProducts.yearly))
    }
}
