#if os(iOS)
import CoreGraphics

/// Maps Vision body-pose points to SwiftUI overlay coordinates matching a mirrored, aspect-fill front-camera preview.
enum PushupPoseCoordinateMapper {
    /// Portrait front-camera buffer aspect (vga 480×640).
    static let contentAspect: CGFloat = 3.0 / 4.0

    static func aspectFillRect(in viewSize: CGSize, contentAspect: CGFloat = contentAspect) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0 else { return .zero }
        let viewAspect = viewSize.width / viewSize.height
        if viewAspect > contentAspect {
            let height = viewSize.height
            let width = height * contentAspect
            let x = (viewSize.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        }
        let width = viewSize.width
        let height = width / contentAspect
        let y = (viewSize.height - height) / 2
        return CGRect(x: 0, y: y, width: width, height: height)
    }

    /// Vision normalized point (origin bottom-left) → view coordinates for mirrored selfie preview.
    static func mapVisionPoint(_ point: CGPoint, to viewSize: CGSize) -> CGPoint {
        let mirroredTopLeft = CGPoint(x: 1 - point.x, y: 1 - point.y)
        return mapNormalizedTopLeft(mirroredTopLeft, to: viewSize)
    }

    static func mapNormalizedTopLeft(_ point: CGPoint, to viewSize: CGSize) -> CGPoint {
        let rect = aspectFillRect(in: viewSize)
        return CGPoint(
            x: rect.minX + point.x * rect.width,
            y: rect.minY + point.y * rect.height
        )
    }

    static func mapVisionRect(_ rect: CGRect, to viewSize: CGSize) -> CGRect {
        let bottomLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let mappedBottomLeft = mapVisionPoint(bottomLeft, to: viewSize)
        let mappedTopRight = mapVisionPoint(topRight, to: viewSize)
        return CGRect(
            x: min(mappedBottomLeft.x, mappedTopRight.x),
            y: min(mappedBottomLeft.y, mappedTopRight.y),
            width: abs(mappedTopRight.x - mappedBottomLeft.x),
            height: abs(mappedTopRight.y - mappedBottomLeft.y)
        )
    }
}
#endif
