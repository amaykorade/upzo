import XCTest
@testable import timer

final class AccountAuthTests: XCTestCase {
    func testAuthProviderDisplayNames() {
        XCTAssertEqual(AccountAuthProvider.apple.displayName, "Apple")
        XCTAssertEqual(AccountAuthProvider.google.displayName, "Google")
        XCTAssertEqual(AccountAuthProvider.none.displayName, "Not signed in")
    }
}
