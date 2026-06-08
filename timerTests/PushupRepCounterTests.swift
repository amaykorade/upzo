import XCTest
@testable import timer

final class PushupRepCounterTests: XCTestCase {
    private let thresholds = PushupRepThresholds(downAngleDegrees: 110, upAngleDegrees: 145, minSecondsBetweenReps: 0.4)
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 1_001)

    func testElbowAngleAtRightAngle() {
        let angle = PushupPoseMath.elbowAngleDegrees(
            shoulder: CGPoint(x: 0, y: 1),
            elbow: CGPoint(x: 0, y: 0),
            wrist: CGPoint(x: 1, y: 0)
        )
        XCTAssertEqual(angle ?? -1, 90, accuracy: 0.5)
    }

    func testRepCountsOnDownThenUpTransition() {
        var counter = PushupRepCounter(thresholds: thresholds)

        XCTAssertNil(counter.update(elbowAngleDegrees: 150, now: t0))
        XCTAssertEqual(counter.phase, .up)

        XCTAssertNil(counter.update(elbowAngleDegrees: 100, now: t0))
        XCTAssertEqual(counter.phase, .down)

        XCTAssertEqual(counter.update(elbowAngleDegrees: 150, now: t1), 1)
        XCTAssertEqual(counter.reps, 1)
    }

    func testRepDoesNotCountWithoutDownPhase() {
        var counter = PushupRepCounter(thresholds: thresholds)

        XCTAssertNil(counter.update(elbowAngleDegrees: 150, now: t0))
        XCTAssertNil(counter.update(elbowAngleDegrees: 150, now: t1))
        XCTAssertEqual(counter.reps, 0)
    }

    func testRepRespectsMinimumInterval() {
        var counter = PushupRepCounter(thresholds: thresholds)
        let tooSoon = Date(timeIntervalSince1970: 1_000.2)

        _ = counter.update(elbowAngleDegrees: 150, now: t0)
        _ = counter.update(elbowAngleDegrees: 100, now: t0)
        XCTAssertEqual(counter.update(elbowAngleDegrees: 150, now: t0), 1)

        _ = counter.update(elbowAngleDegrees: 100, now: tooSoon)
        XCTAssertNil(counter.update(elbowAngleDegrees: 150, now: tooSoon))
        XCTAssertEqual(counter.reps, 1)
    }

    func testResetClearsState() {
        var counter = PushupRepCounter(thresholds: thresholds)
        _ = counter.update(elbowAngleDegrees: 150, now: t0)
        _ = counter.update(elbowAngleDegrees: 100, now: t0)
        _ = counter.update(elbowAngleDegrees: 150, now: t1)

        counter.reset()
        XCTAssertEqual(counter.reps, 0)
        XCTAssertEqual(counter.phase, .unknown)
    }

    func testThresholdsScaleWithVerificationLevel() {
        let normal = PushupRepThresholds.forLevel(.normal)
        let strict = PushupRepThresholds.forLevel(.strict)

        XCTAssertLessThan(strict.downAngleDegrees, normal.downAngleDegrees)
        XCTAssertGreaterThan(strict.upAngleDegrees, normal.upAngleDegrees)
    }

    func testMissionRequirementsPushupCounts() {
        let normal = MissionRequirements(verificationLevel: .normal)
        let strict = MissionRequirements(verificationLevel: .strict)

        XCTAssertEqual(normal.requiredPushupCount, 10)
        XCTAssertEqual(strict.requiredPushupCount, 15)
        XCTAssertLessThan(normal.requiredPushupCount, strict.requiredPushupCount)
    }
}
