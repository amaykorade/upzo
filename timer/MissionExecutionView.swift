#if os(iOS)
import AudioToolbox
import AVFoundation
import Combine
import CoreMotion
import PhotosUI
import Speech
import SwiftUI
import UIKit

private func dismissSoftwareKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// Loops the alarm tone for the whole wake-up mission. Started as soon as the mission is presented
/// (not only when `MissionExecutionView` finishes animating) so there is no silent gap after notifications stop.
@MainActor
final class MissionDuringAlarmAudio {
    static let shared = MissionDuringAlarmAudio()

    private var player: AVAudioPlayer?
    private var fallbackTimer: Timer?
    private var activeAlarmId: UUID?

    private init() {}

    /// Idempotent: safe to call from `ContentView` and `MissionExecutionView`.
    func start(alarm: Alarm, enabled: Bool, mixWithRecording: Bool) {
        guard enabled else {
            stop()
            return
        }
        guard activeAlarmId != alarm.id else { return }

        stop()
        activeAlarmId = alarm.id

        let session = AVAudioSession.sharedInstance()
        do {
            if mixWithRecording {
                try session.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: [.defaultToSpeaker, .mixWithOthers, .duckOthers, .allowBluetoothHFP]
                )
            } else {
                try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            }
            try session.setActive(true, options: [])
            try? session.overrideOutputAudioPort(.speaker)
        } catch {
            startFallbackAlertLoop(for: alarm.id)
            return
        }

        if let url = alarm.alarmSound.bundleURL,
           let p = try? AVAudioPlayer(contentsOf: url) {
            p.numberOfLoops = -1
            p.volume = mixWithRecording ? 0.55 : 1.0
            p.prepareToPlay()
            if p.play() {
                player = p
                Task { await AlarmNotificationManager.shared.cancelSustainNotifications(for: alarm.id) }
                return
            }
        }

        startFallbackAlertLoop(for: alarm.id)
    }

    private func startFallbackAlertLoop(for alarmId: UUID) {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        fallbackTimer?.invalidate()
        let timer = Timer(timeInterval: 0.9, repeats: true) { _ in
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
        fallbackTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        Task { await AlarmNotificationManager.shared.cancelSustainNotifications(for: alarmId) }
    }

    func stop() {
        activeAlarmId = nil
        player?.stop()
        player = nil
        fallbackTimer?.invalidate()
        fallbackTimer = nil

        let session = AVAudioSession.sharedInstance()
        try? session.overrideOutputAudioPort(.none)
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

/// Repeating haptics during a strict mission — still noticeable when media/ring volume is low.
private final class MissionStrictHaptics: ObservableObject {
    private var timer: Timer?

    func startIfNeeded(strictAlarm: Bool) {
        guard strictAlarm else { return }
        stop()
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.prepare()
        impact.impactOccurred(intensity: 1.0)
        var n = 0
        let t = Timer(timeInterval: 1.1, repeats: true) { _ in
            n += 1
            impact.impactOccurred(intensity: 1.0)
            if n % 4 == 0 {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct MissionExecutionView: View {
    let alarm: Alarm
    var allowsDismissWithoutMission: Bool = false
    var onMissionCompleted: () -> Void
    var onDismiss: () -> Void

    @EnvironmentObject private var appSettings: AlarmAppSettingsStore
    @StateObject private var missionStrictHaptics = MissionStrictHaptics()
    @State private var isSchedulingSnooze = false
    @State private var showSuccessCelebration = false
    @State private var successCelebrationMessage: String?
    @State private var successShareSnapshot: MissionShareSnapshot?
    @State private var successHuntTarget: HuntObject?

    private var isStrictMission: Bool {
        !allowsDismissWithoutMission && appSettings.missionVerificationLevel == .strict
    }

    private var requirements: MissionRequirements {
        appSettings.missionRequirements
    }

    private var canShowSnooze: Bool {
        !allowsDismissWithoutMission
            && appSettings.snoozeEnabled
            && MissionSnoozeController.shared.canSnooze(alarmId: alarm.id)
    }

    private var isPushupsMission: Bool {
        alarm.missionType == .pushups
    }

    var body: some View {
        ZStack {
            missionShell
                .allowsHitTesting(!showSuccessCelebration)

            if showSuccessCelebration, let successShareSnapshot {
                MissionSuccessView(snapshot: successShareSnapshot) {
                    successCelebrationMessage = nil
                    successHuntTarget = nil
                    self.successShareSnapshot = nil
                    onMissionCompleted()
                }
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.35), value: showSuccessCelebration)
    }

    private var missionShell: some View {
        NavigationStack {
            Group {
                switch alarm.missionType {
                case .shake:
                    ShakeMissionContent(
                        requiredShakes: requirements.requiredShakeCount,
                        isStrict: isStrictMission,
                        onComplete: handleMissionComplete
                    )
                case .photo:
                    PhotoMissionContent(
                        requirements: requirements,
                        onComplete: handleMissionComplete
                    )
                case .text:
                    TextMissionContent(
                        requirements: requirements,
                        onComplete: handleMissionComplete
                    )
                case .voice:
                    VoiceMissionContent(
                        requirements: requirements,
                        onComplete: handleMissionComplete
                    )
                case .readBible:
                    ReadingMissionContent(
                        title: "Read Bible",
                        subtitle: "Read calmly, scroll to the end, then confirm.",
                        lines: MissionReadingContent.bibleLines,
                        requiredSeconds: requirements.requiredReadingSeconds,
                        onComplete: handleMissionComplete
                    )
                case .affirmations:
                    ReadingMissionContent(
                        title: "Morning affirmations",
                        subtitle: "Read each line out loud and complete the timer.",
                        lines: MissionReadingContent.affirmationLines,
                        requiredSeconds: requirements.requiredReadingSeconds,
                        onComplete: handleMissionComplete
                    )
                case .math:
                    MathMissionContent(
                        requirements: requirements,
                        onComplete: handleMissionComplete
                    )
                case .steps:
                    StepsMissionContent(
                        requiredSteps: requirements.requiredStepCount,
                        isStrict: isStrictMission,
                        onComplete: handleMissionComplete
                    )
                case .pushups:
                    PushupMissionContent(
                        requiredReps: requirements.requiredPushupCount,
                        isStrict: isStrictMission,
                        onComplete: handleMissionComplete
                    )
                case .objectHunt:
                    ObjectHuntMissionContent(
                        requirements: requirements,
                        onComplete: handleObjectHuntComplete
                    )
                }
            }
            .navigationTitle("Wake up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(isPushupsMission ? .hidden : .visible, for: .navigationBar)
            .overlay(alignment: .topTrailing) {
                if isPushupsMission, canShowSnooze {
                    pushupsSnoozeButton
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !allowsDismissWithoutMission, !isPushupsMission {
                    VStack(spacing: 6) {
                        if appSettings.vibrationEnabled || appSettings.alarmDuringMissionEnabled {
                            Text("Lowering volume won’t skip this wake-up — finish the mission to stop the alarm.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        if isStrictMission {
                            Text("Strict verification is on.")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .toolbar {
                if canShowSnooze {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            guard !isSchedulingSnooze else { return }
                            isSchedulingSnooze = true
                            MissionDuringAlarmAudio.shared.stop()
                            missionStrictHaptics.stop()
                            Task {
                                await MissionSnoozeController.shared.scheduleSnooze(
                                    for: alarm.id,
                                    sound: alarm.alarmSound
                                )
                                await MainActor.run {
                                    isSchedulingSnooze = false
                                    onDismiss()
                                }
                            }
                        } label: {
                            Text(isSchedulingSnooze ? "Snoozing…" : "Snooze 5m")
                        }
                        .disabled(isSchedulingSnooze)
                    }
                }
                if allowsDismissWithoutMission {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            onDismiss()
                        }
                    }
                }
            }
            .onAppear {
                guard !allowsDismissWithoutMission else { return }
                if appSettings.vibrationEnabled {
                    missionStrictHaptics.startIfNeeded(strictAlarm: true)
                }
                MissionDuringAlarmAudio.shared.start(
                    alarm: alarm,
                    enabled: appSettings.alarmDuringMissionEnabled,
                    mixWithRecording: alarm.missionType == .voice
                )
            }
            .onDisappear {
                MissionDuringAlarmAudio.shared.stop()
                missionStrictHaptics.stop()
            }
        }
    }

    private func handleObjectHuntComplete(_ target: HuntObject) {
        successHuntTarget = target
        successCelebrationMessage = MissionCringeLines.randomLine(for: .objectHunt, object: target)
        handleMissionComplete()
    }

    private func handleMissionComplete() {
        guard !showSuccessCelebration else { return }
        if allowsDismissWithoutMission {
            onMissionCompleted()
            return
        }
        if successCelebrationMessage == nil {
            successCelebrationMessage = MissionCringeLines.randomLine(for: alarm.missionType)
        }
        let completedAt = Date()
        successShareSnapshot = MissionShareFormatting.snapshot(
            missionTitle: alarm.missionType.title,
            celebrationMessage: successCelebrationMessage ?? alarm.missionType.title,
            completedAt: completedAt,
            huntTarget: successHuntTarget
        )
        MissionDuringAlarmAudio.shared.stop()
        missionStrictHaptics.stop()
        showSuccessCelebration = true
    }

    private var pushupsSnoozeButton: some View {
        Button {
            guard !isSchedulingSnooze else { return }
            isSchedulingSnooze = true
            MissionDuringAlarmAudio.shared.stop()
            missionStrictHaptics.stop()
            Task {
                await MissionSnoozeController.shared.scheduleSnooze(
                    for: alarm.id,
                    sound: alarm.alarmSound
                )
                await MainActor.run {
                    isSchedulingSnooze = false
                    onDismiss()
                }
            }
        } label: {
            Text(isSchedulingSnooze ? "Snoozing…" : "Snooze 5m")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.black.opacity(0.45), in: Capsule())
        }
        .disabled(isSchedulingSnooze)
    }
}

// MARK: - Shake

private final class ShakeSensor: ObservableObject {
    private let motion = CMMotionManager()
    private let processingQueue = OperationQueue()

    @Published private(set) var shakeCount = 0

    private var lastPeakTime: TimeInterval = 0

    var requiredShakes = 12

    var isComplete: Bool { shakeCount >= requiredShakes }

    init() {
        processingQueue.name = "timer.shake"
        processingQueue.maxConcurrentOperationCount = 1
    }

    func start() {
        guard motion.isAccelerometerAvailable else { return }
        motion.accelerometerUpdateInterval = 0.08
        motion.startAccelerometerUpdates(to: processingQueue) { [weak self] data, _ in
            guard let self, let acceleration = data?.acceleration else { return }
            let magnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z)
            guard magnitude > 2.35 else { return }

            let now = Date().timeIntervalSince1970
            DispatchQueue.main.async {
                self.registerPeak(at: now)
            }
        }
    }

    func stop() {
        motion.stopAccelerometerUpdates()
    }

    private func registerPeak(at time: TimeInterval) {
        guard time - lastPeakTime > 0.32 else { return }
        lastPeakTime = time
        shakeCount += 1
    }
}

private struct ShakeMissionContent: View {
    let requiredShakes: Int
    let isStrict: Bool
    var onComplete: () -> Void

    @StateObject private var sensor = ShakeSensor()
    @State private var didFinish = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Shake your phone")
                .font(.title2.weight(.semibold))

            Text("\(sensor.shakeCount) / \(requiredShakes)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()

            ProgressView(value: Double(sensor.shakeCount), total: Double(requiredShakes))
                .tint(.accentColor)

            Text(
                isStrict
                    ? "Use strong, full-range shakes with steady form — strict mode needs \(requiredShakes) clean reps."
                    : "Each strong shake counts once."
            )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .onAppear {
            sensor.requiredShakes = requiredShakes
            sensor.start()
        }
        .onDisappear {
            sensor.stop()
        }
        .onChange(of: sensor.shakeCount) { _, newValue in
            guard !didFinish, newValue >= requiredShakes else { return }
            didFinish = true
            sensor.stop()
            onComplete()
        }
    }
}

// MARK: - Photo (camera first, library fallback)

private struct PhotoMissionContent: View {
    let requirements: MissionRequirements
    var onComplete: () -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var didFinish = false
    @State private var photoRejected = false
    @State private var isVerifyingLibraryPhoto = false

    private var isStrict: Bool { requirements.photoRequiresCameraOnly }

    private var hasCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(isStrict ? "Outside sky photo" : "Take a photo")
                .font(.title2.weight(.semibold))

            Text(
                isStrict
                    ? "Go outside and photograph the open sky in your camera. Library photos are not accepted in strict mode."
                    : (hasCamera
                        ? "A window sky photo counts. Take a new photo or choose one from your library."
                        : "Choose any photo from your library to dismiss the alarm.")
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            if photoRejected {
                Text("Couldn’t verify a sky photo. Include more bright sky at the top of the frame.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            if isVerifyingLibraryPhoto {
                ProgressView("Checking photo…")
                    .font(.footnote)
            }

            if hasCamera {
                Button {
                    showCamera = true
                } label: {
                    Label(isStrict ? "Open camera (required)" : "Open camera", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                }
            }

            if !isStrict {
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Label(hasCamera ? "Choose from library" : "Choose photo", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showCamera) {
            CameraImagePicker(capturedImage: $cameraImage)
                .ignoresSafeArea()
        }
        .onChange(of: cameraImage) { _, newValue in
            guard !didFinish, let image = newValue else { return }
            acceptPhotoIfValid(image)
        }
        .onChange(of: pickerItem) { _, newValue in
            guard !didFinish, let item = newValue else { return }
            isVerifyingLibraryPhoto = true
            photoRejected = false
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        isVerifyingLibraryPhoto = false
                        acceptPhotoIfValid(image)
                    }
                } else {
                    await MainActor.run {
                        isVerifyingLibraryPhoto = false
                        photoRejected = true
                    }
                }
            }
        }
    }

    private func acceptPhotoIfValid(_ image: UIImage) {
        let passes = MissionVerifiers.photoPassesSkyCheck(
            image,
            minimumTopBrightness: requirements.photoMinimumSkyBrightness
        )
        guard passes else {
            cameraImage = nil
            pickerItem = nil
            photoRejected = true
            return
        }
        photoRejected = false
        didFinish = true
        onComplete()
    }
}

// MARK: - Voice (speech recognition)

private final class VoiceMissionEngine: NSObject, ObservableObject {
    @Published var statusText = "Requesting permissions…"
    @Published var transcript = ""

    let displayPhrase: String
    private let matchPhrase: String

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en_US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var onMatched: (() -> Void)?
    private var matched = false

    init(displayPhrase: String, matchPhrase: String) {
        self.displayPhrase = displayPhrase
        self.matchPhrase = matchPhrase
    }

    func start() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            statusText = "Speech recognition isn’t available on this device."
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.continueAfterSpeechAuth(status)
            }
        }
    }

    private func continueAfterSpeechAuth(_ status: SFSpeechRecognizerAuthorizationStatus) {
        guard status == .authorized else {
            statusText = "Turn on Speech Recognition for Timer in Settings."
            return
        }

        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.continueAfterMic(granted)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.continueAfterMic(granted)
                }
            }
        }
    }

    private func continueAfterMic(_ granted: Bool) {
        guard granted else {
            statusText = "Turn on Microphone for Timer in Settings."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .mixWithOthers, .duckOthers, .allowBluetoothHFP]
            )
            try session.setActive(true, options: [])
            try? session.overrideOutputAudioPort(.speaker)
        } catch {
            statusText = "Could not set up the microphone."
            return
        }

        beginRecognition()
    }

    private func beginRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest = request
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            statusText = "Could not start listening."
            return
        }

        statusText = "Listening… say: \(displayPhrase)"

        guard let recognizer = speechRecognizer else {
            statusText = "Speech recognizer unavailable."
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = text
                    let norm = text.lowercased()
                    if !self.matched, norm.contains(self.matchPhrase) {
                        self.matched = true
                        self.stop()
                        self.onMatched?()
                    }
                }
            }
            if error != nil, !(matched) {
                DispatchQueue.main.async {
                    if self.transcript.isEmpty {
                        self.statusText = "Listening stopped — try again."
                    }
                }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

private struct VoiceMissionContent: View {
    let requirements: MissionRequirements
    var onComplete: () -> Void

    @StateObject private var engine: VoiceMissionEngine
    @State private var didFinish = false

    init(requirements: MissionRequirements, onComplete: @escaping () -> Void) {
        self.requirements = requirements
        self.onComplete = onComplete
        _engine = StateObject(
            wrappedValue: VoiceMissionEngine(
                displayPhrase: requirements.voiceDisplayPhrase,
                matchPhrase: requirements.voicePhrase
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Say the phrase")
                .font(.title2.weight(.semibold))

            Text(engine.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Heard: \(engine.transcript.isEmpty ? "…" : engine.transcript)")
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("Say clearly:")
                Text(engine.displayPhrase).fontWeight(.semibold)
            }
            .font(.footnote)

            Spacer()
        }
        .padding()
        .onAppear {
            engine.onMatched = {
                guard !didFinish else { return }
                didFinish = true
                onComplete()
            }
            engine.start()
        }
        .onDisappear {
            engine.stop()
        }
    }
}

// MARK: - Text

private struct TextMissionContent: View {
    let requirements: MissionRequirements
    var onComplete: () -> Void

    @State private var input = ""
    @FocusState private var fieldFocused: Bool

    private var phrase: String { requirements.textPhrase }

    private var isValid: Bool {
        MissionVerifiers.textMatches(input: input, expectedPhrase: phrase)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Type the phrase")
                .font(.title2.weight(.semibold))

            Text("Type exactly: \(phrase)")
                .font(.body)
                .fontWeight(.medium)

            TextField("Phrase", text: $input)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(.quaternary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                .focused($fieldFocused)

            Button("Done") {
                fieldFocused = false
                dismissSoftwareKeyboard()
                if isValid { onComplete() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(!isValid)

            Spacer()
        }
        .padding()
        .onAppear {
            fieldFocused = true
        }
    }
}

// MARK: - Reading Missions

private enum MissionReadingContent {
    static let bibleLines: [String] = [
        "This is the day that the Lord has made; let us rejoice and be glad in it.",
        "I can do all things through Christ who strengthens me.",
        "Commit your work to the Lord, and your plans will be established.",
        "Teach us to number our days, that we may gain a heart of wisdom."
    ]
    static let affirmationLines: [String] = ["I wake up with energy.", "I act now.", "I keep promises to myself.", "I win this morning."]
}

private struct ReadingMissionContent: View {
    let title: String
    let subtitle: String
    let lines: [String]
    let requiredSeconds: Int
    var onComplete: () -> Void

    @State private var hasScrolledToEnd = false
    @State private var secondsRemaining: Int

    init(
        title: String,
        subtitle: String,
        lines: [String],
        requiredSeconds: Int,
        onComplete: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.lines = lines
        self.requiredSeconds = requiredSeconds
        self.onComplete = onComplete
        _secondsRemaining = State(initialValue: requiredSeconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title2.weight(.semibold))
            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            Text("Stay here for \(secondsRemaining)s and scroll to end.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(lines.indices, id: \.self) { idx in
                        Text("\(idx + 1). \(lines[idx])")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear.frame(height: 1).onAppear { hasScrolledToEnd = true }
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))

            Button("I read this") { onComplete() }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(!hasScrolledToEnd || secondsRemaining > 0)
            Spacer()
        }
        .padding()
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard secondsRemaining > 0 else { return }
            secondsRemaining -= 1
        }
    }
}

// MARK: - Math
private struct MathMissionContent: View {
    let requirements: MissionRequirements
    var onComplete: () -> Void

    @State private var challenge: MissionVerifiers.MathChallenge
    @State private var answerInput = ""
    @FocusState private var fieldFocused: Bool

    init(requirements: MissionRequirements, onComplete: @escaping () -> Void) {
        self.requirements = requirements
        self.onComplete = onComplete
        _challenge = State(
            initialValue: MissionVerifiers.generateMathChallenge(level: requirements.verificationLevel)
        )
    }

    private var isValid: Bool {
        MissionVerifiers.mathAnswerMatches(input: answerInput, expected: challenge.answer)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Solve to dismiss")
                .font(.title2.weight(.semibold))

            Text(challenge.prompt)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()

            TextField("Your answer", text: $answerInput)
                .keyboardType(.numberPad)
                .padding()
                .background(.quaternary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                .focused($fieldFocused)

            Button("Submit") {
                fieldFocused = false
                dismissSoftwareKeyboard()
                if isValid { onComplete() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(!isValid)

            Spacer()
        }
        .padding()
        .onAppear {
            fieldFocused = true
        }
    }
}

// MARK: - Steps

private final class StepCounter: ObservableObject {
    @Published private(set) var steps = 0
    @Published private(set) var statusText = "Starting step counter…"

    private let pedometer = CMPedometer()
    private let startedAt = Date()

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    func start() {
        guard isAvailable else {
            statusText = "Step counting isn’t available on this device."
            return
        }
        statusText = "Walk to count steps…"
        pedometer.startUpdates(from: startedAt) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.statusText = error.localizedDescription
                    return
                }
                self.steps = data?.numberOfSteps.intValue ?? 0
            }
        }
    }

    func stop() {
        pedometer.stopUpdates()
    }
}

private struct StepsMissionContent: View {
    let requiredSteps: Int
    let isStrict: Bool
    var onComplete: () -> Void

    @StateObject private var counter = StepCounter()
    @State private var didFinish = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Walk it off")
                .font(.title2.weight(.semibold))

            Text("\(counter.steps) / \(requiredSteps)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()

            ProgressView(value: Double(min(counter.steps, requiredSteps)), total: Double(requiredSteps))

            Text(counter.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if isStrict {
                Text("Strict mode needs more steps before the alarm stops.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            counter.start()
        }
        .onDisappear {
            counter.stop()
        }
        .onChange(of: counter.steps) { _, newValue in
            guard !didFinish, newValue >= requiredSteps else { return }
            didFinish = true
            counter.stop()
            onComplete()
        }
    }
}

#Preview {
    MissionExecutionView(
        alarm: Alarm(hour: 7, minute: 0, repeatDays: [.monday], scheduleMode: .scheduled, isEnabled: true, missionType: .shake),
        allowsDismissWithoutMission: true,
        onMissionCompleted: {},
        onDismiss: {}
    )
    .environmentObject(AlarmAppSettingsStore.shared)
}
#endif
