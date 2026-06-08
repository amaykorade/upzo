import XCTest
@testable import timer

final class PushupPoseCoordinateMapperTests: XCTestCase {
    func testAspectFillRectPillarsWhenViewIsWide() {
        let rect = PushupPoseCoordinateMapper.aspectFillRect(in: CGSize(width: 400, height: 300))
        XCTAssertEqual(rect.height, 300, accuracy: 0.5)
        XCTAssertLessThan(rect.width, 400)
        XCTAssertGreaterThan(rect.minX, 0)
    }

    func testAspectFillRectLetterboxesWhenViewIsTallAndNarrow() {
        let rect = PushupPoseCoordinateMapper.aspectFillRect(in: CGSize(width: 300, height: 800))
        XCTAssertEqual(rect.width, 300, accuracy: 0.5)
        XCTAssertLessThan(rect.height, 800)
        XCTAssertGreaterThan(rect.minY, 0)
    }

    func testMapVisionCenterToViewCenter() {
        let viewSize = CGSize(width: 300, height: 400)
        let centerVision = CGPoint(x: 0.5, y: 0.5)
        let mapped = PushupPoseCoordinateMapper.mapVisionPoint(centerVision, to: viewSize)
        let fill = PushupPoseCoordinateMapper.aspectFillRect(in: viewSize)
        XCTAssertEqual(mapped.x, fill.midX, accuracy: 1)
        XCTAssertEqual(mapped.y, fill.midY, accuracy: 1)
    }

    func testMirroredMappingFlipsHorizontalAxis() {
        let viewSize = CGSize(width: 300, height: 400)
        let leftVision = CGPoint(x: 0.2, y: 0.5)
        let rightVision = CGPoint(x: 0.8, y: 0.5)
        let mappedLeft = PushupPoseCoordinateMapper.mapVisionPoint(leftVision, to: viewSize)
        let mappedRight = PushupPoseCoordinateMapper.mapVisionPoint(rightVision, to: viewSize)
        XCTAssertGreaterThan(mappedLeft.x, mappedRight.x)
    }
}
