#if os(iOS)
import AVFoundation
import Combine
import Vision

@MainActor
final class PushupPoseSession: NSObject, ObservableObject {
    @Published private(set) var reps = 0
    @Published private(set) var statusText = "Starting camera…"
    @Published private(set) var coachingHint = ""
    @Published private(set) var isReadyForStart = false
    @Published private(set) var isReadyLatched = false
    @Published private(set) var isAvailable = true
    @Published private(set) var overlayModel = PushupPoseOverlayModel.empty
    @Published private(set) var visibility: PushupBodyVisibilityState = .searching

    let captureSession = AVCaptureSession()

    private var repCounter: PushupRepCounter
    private var isCounting = false
    private var readyLatch = PushupReadyLatch()
    private let videoQueue = DispatchQueue(label: "timer.pushup.video", qos: .userInitiated)
    private let frameGate = PushupFrameGate()

    init(thresholds: PushupRepThresholds) {
        repCounter = PushupRepCounter(thresholds: thresholds)
        super.init()
    }

    func start() async {
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil else {
            isAvailable = false
            statusText = "Front camera is not available on this device."
            return
        }

        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            granted = true
        case .notDetermined:
            granted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            granted = false
        }

        guard granted else {
            isAvailable = false
            statusText = "Allow camera access in Settings to count pushups."
            return
        }

        await configureSessionIfNeeded()
        guard isAvailable else { return }

        let session = captureSession
        videoQueue.async {
            session.startRunning()
        }
        statusText = "Step into view"
    }

    func beginCounting() {
        isCounting = true
        repCounter.reset()
        reps = 0
        coachingHint = ""
        statusText = "Go!"
    }

    func stop() {
        isCounting = false
        let session = captureSession
        videoQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configureSessionIfNeeded() async {
        guard captureSession.inputs.isEmpty else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        defer { captureSession.commitConfiguration() }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input)
        else {
            isAvailable = false
            statusText = "Could not open the front camera."
            return
        }
        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        guard captureSession.canAddOutput(output) else {
            isAvailable = false
            statusText = "Could not start pushup detection."
            return
        }
        captureSession.addOutput(output)
    }

    fileprivate func handlePoseObservation(_ observation: VNHumanBodyPoseObservation) {
        let tracked = PushupTrackedJoints.from(observation: observation)
        let visibilityMode: PushupBodyVisibilityMode = isCounting ? .counting : .setup
        let visibility = PushupBodyVisibilityEvaluator.evaluate(joints: tracked, mode: visibilityMode)
        self.visibility = visibility
        overlayModel = PushupPoseOverlayModel.from(observation: observation, visibility: visibility)

        let angle = Self.bestElbowAngle(from: observation)

        if isCounting {
            if let angle {
                if let newTotal = repCounter.update(elbowAngleDegrees: angle) {
                    reps = newTotal
                    coachingHint = ""
                } else {
                    updateCoaching(angle: angle)
                }
            } else {
                coachingHint = "Stay visible — keep arms in frame"
            }
        } else {
            updateSetupReadiness(visibility: visibility)
        }
    }

    private func updateSetupReadiness(visibility: PushupBodyVisibilityState) {
        readyLatch.refreshIfReady(visibility.isReady)
        let latched = readyLatch.isActive()
        isReadyForStart = visibility.isReady || latched
        isReadyLatched = latched && !visibility.isReady

        if visibility.isReady {
            statusText = "Ready — tap Start counting"
            coachingHint = ""
        } else if latched {
            statusText = "Tap Start counting — you have a few seconds"
            coachingHint = ""
        } else {
            statusText = "Position yourself"
            coachingHint = visibility.coachingMessage
        }
    }

    private func updateCoaching(angle: Double) {
        switch repCounter.phase {
        case .down:
            coachingHint = "Push up"
        case .up, .unknown:
            coachingHint = angle < repCounter.thresholds.upAngleDegrees ? "Go lower" : ""
        }
    }

    private static func bestElbowAngle(from observation: VNHumanBodyPoseObservation) -> Double? {
        let left = elbowAngle(
            observation: observation,
            shoulder: .leftShoulder,
            elbow: .leftElbow,
            wrist: .leftWrist
        )
        let right = elbowAngle(
            observation: observation,
            shoulder: .rightShoulder,
            elbow: .rightElbow,
            wrist: .rightWrist
        )

        switch (left, right) {
        case let (.some(l), .some(r)):
            return (l + r) / 2
        case let (.some(l), .none):
            return l
        case let (.none, .some(r)):
            return r
        case (.none, .none):
            return nil
        }
    }

    private static func elbowAngle(
        observation: VNHumanBodyPoseObservation,
        shoulder: VNHumanBodyPoseObservation.JointName,
        elbow: VNHumanBodyPoseObservation.JointName,
        wrist: VNHumanBodyPoseObservation.JointName
    ) -> Double? {
        guard let shoulderPoint = try? observation.recognizedPoint(shoulder),
              let elbowPoint = try? observation.recognizedPoint(elbow),
              let wristPoint = try? observation.recognizedPoint(wrist),
              shoulderPoint.confidence > 0.3,
              elbowPoint.confidence > 0.3,
              wristPoint.confidence > 0.3
        else { return nil }

        return PushupPoseMath.elbowAngleDegrees(
            shoulder: shoulderPoint.location,
            elbow: elbowPoint.location,
            wrist: wristPoint.location
        )
    }
}

private final class PushupFrameGate: @unchecked Sendable {
    private var counter = 0

    func shouldProcess() -> Bool {
        counter += 1
        return counter % 3 == 0
    }
}

extension PushupPoseSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard frameGate.shouldProcess() else { return }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .leftMirrored, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first as? VNHumanBodyPoseObservation else { return }
            Task { @MainActor [weak self] in
                self?.handlePoseObservation(observation)
            }
        } catch {
            return
        }
    }
}
#endif
