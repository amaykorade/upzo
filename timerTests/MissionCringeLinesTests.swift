import XCTest
@testable import timer

final class MissionCringeLinesTests: XCTestCase {
    func testEveryMissionTypeHasCringeLines() {
        for mission in MissionType.allCases {
            let line = MissionCringeLines.randomLine(for: mission)
            XCTAssertFalse(line.isEmpty, "Missing cringe line for \(mission.rawValue)")
        }
    }

    func testObjectHuntPrefersObjectSpecificLine() {
        let mug = HuntObjectCatalog.object(withId: "coffee_mug")!
        for _ in 0 ..< 20 {
            let line = MissionCringeLines.randomLine(for: .objectHunt, object: mug)
            XCTAssertNotNil(line)
            XCTAssertFalse(line.isEmpty)
        }
    }
}
