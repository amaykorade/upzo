#if os(iOS)
import AVFoundation
import Combine
import UIKit

@MainActor
final class ObjectHuntCameraSession: NSObject, ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var statusText = "Starting camera…"

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    func start() async {
        guard !captureSession.isRunning else {
            isAvailable = true
            return
        }

        let granted = await Self.requestCameraAccess()
        guard granted else {
            isAvailable = false
            statusText = "Allow camera access in Settings to photograph your object."
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input)
        else {
            captureSession.commitConfiguration()
            isAvailable = false
            statusText = "Rear camera isn’t available on this device."
            return
        }

        captureSession.addInput(input)

        guard captureSession.canAddOutput(photoOutput) else {
            captureSession.commitConfiguration()
            isAvailable = false
            statusText = "Couldn’t prepare the camera for photos."
            return
        }
        captureSession.addOutput(photoOutput)
        captureSession.commitConfiguration()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                continuation.resume()
            }
        }

        isAvailable = true
        statusText = ""
    }

    func stop() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    func capturePhoto() async -> UIImage? {
        guard isAvailable else { return nil }
        if let connection = photoOutput.connection(with: .video) {
            let angle = Self.currentVideoRotationAngle()
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private static func currentVideoRotationAngle() -> CGFloat {
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
        return 90
    }

    private static func requestCameraAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
}

extension ObjectHuntCameraSession: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image: UIImage?
        if let data = photo.fileDataRepresentation() {
            image = UIImage(data: data)
        } else {
            image = nil
        }
        Task { @MainActor in
            captureContinuation?.resume(returning: image)
            captureContinuation = nil
        }
    }
}
#endif
