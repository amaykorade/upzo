#if os(iOS)
import XCTest
@testable import timer

@MainActor
final class MissionSocialShareTests: XCTestCase {
    func testShareFormattingIncludesWakeTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 2
        components.hour = 6
        components.minute = 42
        let date = Calendar.current.date(from: components)!

        let snapshot = MissionShareFormatting.snapshot(
            missionTitle: "Object hunt",
            celebrationMessage: "Found the coffee mug.",
            completedAt: date
        )

        XCTAssertEqual(snapshot.missionTitle, "Object hunt")
        XCTAssertEqual(snapshot.celebrationMessage, "Found the coffee mug.")
        XCTAssertFalse(snapshot.wakeUpTime.isEmpty)
        XCTAssertFalse(snapshot.wakeUpDate.isEmpty)
    }

    func testObjectHuntSnapshotIncludesTarget() {
        let orange = HuntObjectCatalog.object(withId: "orange")!
        let snapshot = MissionShareFormatting.snapshot(
            missionTitle: "Object hunt",
            celebrationMessage: "Found the orange.",
            huntTarget: orange
        )

        XCTAssertTrue(snapshot.isObjectHuntShare)
        XCTAssertEqual(snapshot.huntTargetName, "Orange")
        XCTAssertEqual(snapshot.huntTargetSystemImage, orange.systemImage)
    }

    func testRenderShareImageProducesBitmap() {
        let snapshot = MissionShareFormatting.snapshot(
            missionTitle: "Object hunt",
            celebrationMessage: "Found the coffee mug. Still searching for your future.",
            huntTarget: HuntObjectCatalog.object(withId: "coffee_mug")
        )
        let image = MissionSocialShare.renderImage(snapshot: snapshot)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size.width, MissionShareCardView.exportSize.width)
        XCTAssertEqual(image?.size.height, MissionShareCardView.exportSize.height)
    }
}
#endif
