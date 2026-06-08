#if os(iOS)
import Foundation

struct PushupRepThresholds: Equatable {
    let downAngleDegrees: Double
    let upAngleDegrees: Double
    let minSecondsBetweenReps: TimeInterval

    static func forLevel(_ level: MissionVerificationLevel) -> PushupRepThresholds {
        switch level {
        case .normal:
            return PushupRepThresholds(downAngleDegrees: 110, upAngleDegrees: 145, minSecondsBetweenReps: 0.4)
        case .strict:
            return PushupRepThresholds(downAngleDegrees: 95, upAngleDegrees: 150, minSecondsBetweenReps: 0.4)
        }
    }
}

enum PushupRepPhase: Equatable {
    case unknown
    case up
    case down
}

struct PushupRepCounter {
    private(set) var reps = 0
    private(set) var phase: PushupRepPhase = .unknown
    private var lastRepAt: Date?
    let thresholds: PushupRepThresholds

    init(thresholds: PushupRepThresholds) {
        self.thresholds = thresholds
    }

    mutating func reset() {
        reps = 0
        phase = .unknown
        lastRepAt = nil
    }

    @discardableResult
    mutating func update(elbowAngleDegrees: Double?, now: Date = Date()) -> Int? {
        guard let angle = elbowAngleDegrees else { return nil }

        let newPhase: PushupRepPhase
        if angle <= thresholds.downAngleDegrees {
            newPhase = .down
        } else if angle >= thresholds.upAngleDegrees {
            newPhase = .up
        } else {
            return nil
        }

        var incremented: Int?
        if phase == .down, newPhase == .up {
            if let lastRepAt, now.timeIntervalSince(lastRepAt) < thresholds.minSecondsBetweenReps {
                phase = newPhase
                return nil
            }
            reps += 1
            lastRepAt = now
            incremented = reps
        }

        phase = newPhase
        return incremented
    }
}

enum PushupPoseMath {
    static func elbowAngleDegrees(shoulder: CGPoint, elbow: CGPoint, wrist: CGPoint) -> Double? {
        let upper = CGVector(dx: shoulder.x - elbow.x, dy: shoulder.y - elbow.y)
        let forearm = CGVector(dx: wrist.x - elbow.x, dy: wrist.y - elbow.y)
        let upperLen = hypot(upper.dx, upper.dy)
        let forearmLen = hypot(forearm.dx, forearm.dy)
        guard upperLen > 0.001, forearmLen > 0.001 else { return nil }

        let dot = upper.dx * forearm.dx + upper.dy * forearm.dy
        let cosine = max(-1, min(1, dot / (upperLen * forearmLen)))
        return acos(cosine) * 180 / .pi
    }
}
#endif
