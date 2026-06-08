#if os(iOS)
import CoreGraphics
import Vision

enum PushupBodyVisibilityState: Equatable {
    case searching
    case tooClose
    case tooFar
    case offCenter
    case armsMissing
    case ready

    var coachingMessage: String {
        switch self {
        case .searching:
            return "Prop your phone and step into view"
        case .tooClose:
            return "Step back — show your full upper body"
        case .tooFar:
            return "Move closer to the camera"
        case .offCenter:
            return "Center yourself in the frame"
        case .armsMissing:
            return "Keep both arms visible"
        case .ready:
            return "You're in frame — tap Start counting"
        }
    }

    var isReady: Bool { self == .ready }
}

enum PushupBodyVisibilityMode: Equatable {
    /// Standing/kneeling framing check before countdown — no pushup pose required.
    case setup
    /// Stricter check when validating full arm chains (overlay / counting coaching).
    case counting
}

struct PushupTrackedJoints: Equatable {
    var neck: CGPoint?
    var leftShoulder: CGPoint?
    var rightShoulder: CGPoint?
    var leftElbow: CGPoint?
    var rightElbow: CGPoint?
    var leftWrist: CGPoint?
    var rightWrist: CGPoint?
    var root: CGPoint?
    var leftHip: CGPoint?
    var rightHip: CGPoint?

    static let minimumConfidence: Float = 0.25

    static func from(observation: VNHumanBodyPoseObservation) -> PushupTrackedJoints {
        func point(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let recognized = try? observation.recognizedPoint(joint),
                  recognized.confidence >= minimumConfidence
            else { return nil }
            return recognized.location
        }

        return PushupTrackedJoints(
            neck: point(.neck) ?? point(.nose),
            leftShoulder: point(.leftShoulder),
            rightShoulder: point(.rightShoulder),
            leftElbow: point(.leftElbow),
            rightElbow: point(.rightElbow),
            leftWrist: point(.leftWrist),
            rightWrist: point(.rightWrist),
            root: point(.root),
            leftHip: point(.leftHip),
            rightHip: point(.rightHip)
        )
    }

    var leftArmComplete: Bool {
        leftShoulder != nil && leftElbow != nil && leftWrist != nil
    }

    var rightArmComplete: Bool {
        rightShoulder != nil && rightElbow != nil && rightWrist != nil
    }
}

enum PushupBodyVisibilityEvaluator {
    private static let tooCloseShoulderSpan: CGFloat = 0.72
    private static let tooFarShoulderSpan: CGFloat = 0.18
    private static let offCenterThreshold: CGFloat = 0.22

    static func evaluate(
        joints: PushupTrackedJoints,
        mode: PushupBodyVisibilityMode = .counting
    ) -> PushupBodyVisibilityState {
        guard joints.leftShoulder != nil || joints.rightShoulder != nil else {
            return .searching
        }

        if joints.neck == nil {
            return .searching
        }

        guard let left = joints.leftShoulder, let right = joints.rightShoulder else {
            return .armsMissing
        }

        let shoulderSpan = abs(right.x - left.x)
        if shoulderSpan > tooCloseShoulderSpan {
            return .tooClose
        }
        if shoulderSpan < tooFarShoulderSpan {
            return .tooFar
        }

        let torsoCenterX = (left.x + right.x) / 2
        if abs(torsoCenterX - 0.5) > offCenterThreshold {
            return .offCenter
        }

        let hasTorso = joints.root != nil || (joints.leftHip != nil && joints.rightHip != nil)
        guard hasTorso else {
            return .searching
        }

        switch mode {
        case .setup:
            return .ready
        case .counting:
            guard joints.leftArmComplete || joints.rightArmComplete else {
                return .armsMissing
            }
            if !joints.leftArmComplete || !joints.rightArmComplete {
                return .armsMissing
            }
            return .ready
        }
    }

    static func framingRect(joints: PushupTrackedJoints, padding: CGFloat = 0.08) -> CGRect? {
        var points: [CGPoint] = []
        if let neck = joints.neck { points.append(neck) }
        if let left = joints.leftShoulder { points.append(left) }
        if let right = joints.rightShoulder { points.append(right) }
        if let left = joints.leftElbow { points.append(left) }
        if let right = joints.rightElbow { points.append(right) }
        if let left = joints.leftWrist { points.append(left) }
        if let right = joints.rightWrist { points.append(right) }
        if let root = joints.root { points.append(root) }
        if let left = joints.leftHip { points.append(left) }
        if let right = joints.rightHip { points.append(right) }

        guard points.count >= 3 else { return nil }

        let xs = points.map(\.x)
        let ys = points.map(\.y)
        var rect = CGRect(
            x: xs.min() ?? 0,
            y: ys.min() ?? 0,
            width: (xs.max() ?? 1) - (xs.min() ?? 0),
            height: (ys.max() ?? 1) - (ys.min() ?? 0)
        )
        rect = rect.insetBy(dx: -padding, dy: -padding)
        return CGRect(
            x: max(0, rect.minX),
            y: max(0, rect.minY),
            width: min(1, rect.width),
            height: min(1, rect.height)
        )
    }
}
#endif
