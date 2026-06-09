import XCTest
@testable import timer

final class HuntObjectCringeLinesTests: XCTestCase {
    func testEveryCatalogObjectHasCringeLines() {
        for object in HuntObjectCatalog.all {
            let line = HuntObjectCringeLines.randomLine(for: object)
            XCTAssertNotNil(line, "Missing cringe lines for \(object.id)")
            XCTAssertFalse(line?.isEmpty ?? true)
        }
    }

    func testRandomLineStaysWithinObject() {
        let mug = HuntObjectCatalog.object(withId: "coffee_mug")!
        for _ in 0 ..< 20 {
            let line = HuntObjectCringeLines.randomLine(for: mug)
            XCTAssertNotNil(line)
        }
    }
}
