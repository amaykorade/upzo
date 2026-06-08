#if os(iOS)
import CoreGraphics
import Vision

struct PushupPoseOverlayModel: Equatable {
    struct Joint: Equatable, Identifiable {
        let id: String
        let point: CGPoint
        let confidence: Float
        let isTracked: Bool
    }

    struct Segment: Equatable, Identifiable {
        let id: String
        let start: CGPoint
        let end: CGPoint
        let isTracked: Bool
    }

    var joints: [Joint]
    var segments: [Segment]
    var framingRect: CGRect?
    var visibility: PushupBodyVisibilityState

    static let empty = PushupPoseOverlayModel(
        joints: [],
        segments: [],
        framingRect: nil,
        visibility: .searching
    )

    static func from(
        observation: VNHumanBodyPoseObservation,
        visibility: PushupBodyVisibilityState
    ) -> PushupPoseOverlayModel {
        let tracked = PushupTrackedJoints.from(observation: observation)
        let framing = PushupBodyVisibilityEvaluator.framingRect(joints: tracked)

        func joint(
            _ id: String,
            _ name: VNHumanBodyPoseObservation.JointName,
            point: CGPoint?
        ) -> Joint? {
            guard let point else { return nil }
            guard let recognized = try? observation.recognizedPoint(name) else { return nil }
            return Joint(
                id: id,
                point: point,
                confidence: recognized.confidence,
                isTracked: recognized.confidence >= PushupTrackedJoints.minimumConfidence
            )
        }

        let jointList: [Joint] = [
            joint("neck", .neck, point: tracked.neck),
            joint("leftShoulder", .leftShoulder, point: tracked.leftShoulder),
            joint("rightShoulder", .rightShoulder, point: tracked.rightShoulder),
            joint("leftElbow", .leftElbow, point: tracked.leftElbow),
            joint("rightElbow", .rightElbow, point: tracked.rightElbow),
            joint("leftWrist", .leftWrist, point: tracked.leftWrist),
            joint("rightWrist", .rightWrist, point: tracked.rightWrist),
        ].compactMap { $0 }

        func pointFor(_ id: String) -> CGPoint? {
            jointList.first(where: { $0.id == id })?.point
        }

        var segments: [Segment] = []
        func addSegment(_ id: String, _ startID: String, _ endID: String) {
            guard let start = pointFor(startID), let end = pointFor(endID) else { return }
            let startJoint = jointList.first(where: { $0.id == startID })
            let endJoint = jointList.first(where: { $0.id == endID })
            let trackedBoth = (startJoint?.isTracked ?? false) && (endJoint?.isTracked ?? false)
            segments.append(Segment(id: id, start: start, end: end, isTracked: trackedBoth))
        }

        addSegment("leftUpperArm", "leftShoulder", "leftElbow")
        addSegment("leftForearm", "leftElbow", "leftWrist")
        addSegment("rightUpperArm", "rightShoulder", "rightElbow")
        addSegment("rightForearm", "rightElbow", "rightWrist")
        addSegment("shoulders", "leftShoulder", "rightShoulder")

        return PushupPoseOverlayModel(
            joints: jointList,
            segments: segments,
            framingRect: framing,
            visibility: visibility
        )
    }
}
#endif
