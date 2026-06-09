#if os(iOS)
import AVFoundation
import SwiftUI
import UIKit

struct FrontCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Front-camera missions mirror the preview; rear camera should pass `false`.
    var mirrored: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(mirrored: mirrored)
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        context.coordinator.attach(to: view)
        context.coordinator.applyPreviewSettings(on: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        context.coordinator.applyPreviewSettings(on: uiView)
    }

    final class Coordinator {
        let mirrored: Bool
        private weak var previewView: PreviewView?

        init(mirrored: Bool) {
            self.mirrored = mirrored
        }

        func attach(to view: PreviewView) {
            previewView = view
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(orientationChanged),
                name: UIDevice.orientationDidChangeNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(orientationChanged),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }

        func applyPreviewSettings(on view: PreviewView) {
            guard let connection = view.previewLayer.connection else { return }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }
            applyRotation(to: connection)
        }

        @objc private func orientationChanged() {
            guard let view = previewView else { return }
            applyPreviewSettings(on: view)
        }

        private func applyRotation(to connection: AVCaptureConnection) {
            let angle = Self.videoRotationAngle()
            guard connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }

        private static func videoRotationAngle() -> CGFloat {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
            {
                switch scene.interfaceOrientation {
                case .portrait: return 90
                case .portraitUpsideDown: return 270
                case .landscapeLeft: return 180
                case .landscapeRight: return 0
                default: break
                }
            }

            switch UIDevice.current.orientation {
            case .portrait: return 90
            case .portraitUpsideDown: return 270
            case .landscapeLeft: return 0
            case .landscapeRight: return 180
            default: return 90
            }
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer.frame = bounds
        }
    }
}
#endif
