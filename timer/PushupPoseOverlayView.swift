#if os(iOS)
import SwiftUI

struct PushupPoseOverlayView: View {
    let model: PushupPoseOverlayModel
    var skeletonOpacity: Double = 1

    var body: some View {
        Canvas { context, size in
            drawFramingGuide(context: &context, size: size)
            drawSegments(context: &context, size: size)
            drawJoints(context: &context, size: size)
        }
        .opacity(skeletonOpacity)
        .allowsHitTesting(false)
    }

    private var guideColor: Color {
        model.visibility.isReady ? .green : .orange
    }

    private func drawFramingGuide(context: inout GraphicsContext, size: CGSize) {
        guard let rect = model.framingRect else { return }
        let mapped = PushupPoseCoordinateMapper.mapVisionRect(rect, to: size)
        guard mapped.width > 8, mapped.height > 8 else { return }

        var path = Path(roundedRect: mapped, cornerRadius: 16)
        context.stroke(
            path,
            with: .color(guideColor.opacity(0.85)),
            style: StrokeStyle(lineWidth: 3, dash: model.visibility.isReady ? [] : [10, 8])
        )
    }

    private func drawSegments(context: inout GraphicsContext, size: CGSize) {
        for segment in model.segments {
            let start = PushupPoseCoordinateMapper.mapVisionPoint(segment.start, to: size)
            let end = PushupPoseCoordinateMapper.mapVisionPoint(segment.end, to: size)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            let color: Color = segment.isTracked ? .green : .white.opacity(0.45)
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: segment.isTracked ? 4 : 3,
                    lineCap: .round,
                    dash: segment.isTracked ? [] : [8, 6]
                )
            )
        }
    }

    private func drawJoints(context: inout GraphicsContext, size: CGSize) {
        for joint in model.joints {
            let center = PushupPoseCoordinateMapper.mapVisionPoint(joint.point, to: size)
            let radius: CGFloat = joint.isTracked ? 7 : 5
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let fill: Color = joint.isTracked ? .green : .white.opacity(0.5)
            context.fill(Path(ellipseIn: rect), with: .color(fill))
            context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
        }
    }
}
#endif
