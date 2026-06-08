import XCTest
@testable import timer

final class PushupBodyVisibilityTests: XCTestCase {
    private func readyJoints(
        shoulderSpan: CGFloat = 0.42,
        centerX: CGFloat = 0.5
    ) -> PushupTrackedJoints {
        let half = shoulderSpan / 2
        return PushupTrackedJoints(
            neck: CGPoint(x: centerX, y: 0.82),
            leftShoulder: CGPoint(x: centerX - half, y: 0.72),
            rightShoulder: CGPoint(x: centerX + half, y: 0.72),
            leftElbow: CGPoint(x: centerX - half - 0.05, y: 0.55),
            rightElbow: CGPoint(x: centerX + half + 0.05, y: 0.55),
            leftWrist: CGPoint(x: centerX - half - 0.08, y: 0.38),
            rightWrist: CGPoint(x: centerX + half + 0.08, y: 0.38),
            root: CGPoint(x: centerX, y: 0.58),
            leftHip: CGPoint(x: centerX - 0.12, y: 0.5),
            rightHip: CGPoint(x: centerX + 0.12, y: 0.5)
        )
    }

    func testReadyWhenFullyVisible() {
        let state = PushupBodyVisibilityEvaluator.evaluate(joints: readyJoints())
        XCTAssertEqual(state, .ready)
    }

    func testTooCloseWhenShouldersSpanWide() {
        let state = PushupBodyVisibilityEvaluator.evaluate(joints: readyJoints(shoulderSpan: 0.8))
        XCTAssertEqual(state, .tooClose)
    }

    func testTooFarWhenShouldersSpanNarrow() {
        let state = PushupBodyVisibilityEvaluator.evaluate(joints: readyJoints(shoulderSpan: 0.12))
        XCTAssertEqual(state, .tooFar)
    }

    func testOffCenterWhenTorsoShifted() {
        let state = PushupBodyVisibilityEvaluator.evaluate(joints: readyJoints(centerX: 0.82))
        XCTAssertEqual(state, .offCenter)
    }

    func testSetupReadyWithoutWrists() {
        var joints = readyJoints()
        joints.leftElbow = nil
        joints.rightElbow = nil
        joints.leftWrist = nil
        joints.rightWrist = nil
        let state = PushupBodyVisibilityEvaluator.evaluate(joints: joints, mode: .setup)
        XCTAssertEqual(state, .ready)
    }

    func testArmsMissingWhenOneArmIncompleteInCountingMode() {
        var joints = readyJoints()
        joints.rightWrist = nil
        let state = PushupBodyVisibilityEvaluator.evaluate(joints: joints, mode: .counting)
        XCTAssertEqual(state, .armsMissing)
    }

    func testSearchingWithoutNeck() {
        var joints = readyJoints()
        joints.neck = nil
        let state = PushupBodyVisibilityEvaluator.evaluate(joints: joints)
        XCTAssertEqual(state, .searching)
    }

    func testCoachingMessagesAreNonEmpty() {
        XCTAssertFalse(PushupBodyVisibilityState.tooFar.coachingMessage.isEmpty)
        XCTAssertFalse(PushupBodyVisibilityState.ready.coachingMessage.isEmpty)
    }
}
