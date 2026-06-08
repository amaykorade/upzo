#if os(iOS)
import SwiftUI
import UIKit

private enum PushupMissionPhase {
    case setup
    case countdown
    case counting
}

struct PushupMissionContent: View {
    let requiredReps: Int
    let isStrict: Bool
    var onComplete: () -> Void

    @StateObject private var session: PushupPoseSession
    @State private var phase: PushupMissionPhase = .setup
    @State private var countdownValue = 3
    @State private var didFinish = false

    init(requiredReps: Int, isStrict: Bool, onComplete: @escaping () -> Void) {
        self.requiredReps = requiredReps
        self.isStrict = isStrict
        self.onComplete = onComplete
        let level: MissionVerificationLevel = isStrict ? .strict : .normal
        _session = StateObject(wrappedValue: PushupPoseSession(
            thresholds: PushupRepThresholds.forLevel(level)
        ))
    }

    private var skeletonOpacity: Double {
        phase == .counting ? 0.4 : 1
    }

    var body: some View {
        Group {
            if session.isAvailable {
                cameraExperience
            } else {
                unavailableView
            }
        }
        .task {
            await session.start()
        }
        .onDisappear {
            session.stop()
        }
        .onChange(of: session.reps) { _, newValue in
            guard phase == .counting, !didFinish, newValue >= requiredReps else { return }
            didFinish = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            session.stop()
            onComplete()
        }
        .onChange(of: session.reps) { oldValue, newValue in
            guard phase == .counting, newValue > oldValue else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private var cameraExperience: some View {
        ZStack {
            FrontCameraPreviewView(session: session.captureSession)
                .ignoresSafeArea()

            PushupPoseOverlayView(model: session.overlayModel, skeletonOpacity: skeletonOpacity)
                .ignoresSafeArea()

            if phase == .countdown, countdownValue > 0 {
                Text("\(countdownValue)")
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 12)
            }

            VStack(spacing: 0) {
                topHUD
                Spacer(minLength: 0)
                bottomHUD
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var topHUD: some View {
        VStack(spacing: 8) {
            Text(session.statusText)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if !session.coachingHint.isEmpty {
                Text(session.coachingHint)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            if phase == .setup {
                Text("Stand or kneel facing the camera, then tap Start. You'll get 3 seconds to get into pushup position.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if isStrict, phase != .setup {
                Text("Strict mode — go a bit deeper on each rep.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [.black.opacity(0.72), .black.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var bottomHUD: some View {
        VStack(spacing: 14) {
            if phase == .counting {
                Text("\(session.reps) / \(requiredReps)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.4), radius: 8)

                ProgressView(
                    value: Double(min(session.reps, requiredReps)),
                    total: Double(requiredReps)
                )
                .tint(.green)
                .padding(.horizontal, 8)
            }

            if phase == .setup {
                Button {
                    startCountdown()
                } label: {
                    Text("Start counting")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(session.isReadyForStart ? Color.accentColor : Color.white.opacity(0.25))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
                }
                .disabled(!session.isReadyForStart)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [.clear, .black.opacity(0.45), .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text(session.statusText)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Pushups require a physical iPhone with a front camera.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private func startCountdown() {
        phase = .countdown
        countdownValue = 3
        runCountdownTick()
    }

    private func runCountdownTick() {
        guard countdownValue > 0 else {
            phase = .counting
            session.beginCounting()
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            countdownValue -= 1
            runCountdownTick()
        }
    }
}
#endif
