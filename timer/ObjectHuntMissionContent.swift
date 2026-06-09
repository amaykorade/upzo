#if os(iOS)
import SwiftUI
import UIKit

private enum ObjectHuntPhase {
    case ready
    case capturing
    case verifying
    case rejected
}

struct ObjectHuntMissionContent: View {
    let requirements: MissionRequirements
    var onComplete: () -> Void

    @StateObject private var camera = ObjectHuntCameraSession()
    @State private var target: HuntObject = HuntObjectCatalog.randomTarget()
    @State private var phase: ObjectHuntPhase = .ready
    @State private var didFinish = false

    var body: some View {
        Group {
            if camera.isAvailable {
                cameraExperience
            } else {
                unavailableView
            }
        }
        .task {
            await camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var cameraExperience: some View {
        ZStack {
            FrontCameraPreviewView(session: camera.captureSession, mirrored: false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                targetHUD
                Spacer(minLength: 0)
                bottomHUD
            }
        }
    }

    private var targetHUD: some View {
        VStack(spacing: 10) {
            Text("Object hunt")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: target.systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Photograph this:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(target.displayName)
                        .font(.headline)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))

            if phase == .rejected {
                Text("Couldn’t verify \(target.displayName.lowercased()). Fill the frame, add light, and tap the shutter again.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var bottomHUD: some View {
        VStack(spacing: 12) {
            if phase == .verifying {
                ProgressView("Checking photo…")
                    .font(.footnote)
                    .padding(.bottom, 8)
            } else {
                Button {
                    captureAndVerify()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.9), lineWidth: 4)
                            .frame(width: 74, height: 74)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                    }
                }
                .disabled(phase == .capturing || phase == .verifying)
                .accessibilityLabel("Take photo of \(target.displayName)")
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Text("Object hunt")
                .font(.title2.weight(.semibold))
            targetCard
            Text(camera.statusText.isEmpty ? "A rear camera is required for this mission." : camera.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var targetCard: some View {
        VStack(spacing: 12) {
            Image(systemName: target.systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            Text(target.displayName)
                .font(.title3.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
    }

    private func captureAndVerify() {
        guard !didFinish, phase != .capturing, phase != .verifying else { return }
        phase = .capturing

        Task {
            let image = await camera.capturePhoto()
            guard let image else {
                await MainActor.run { phase = .ready }
                return
            }
            await MainActor.run { verifyPhoto(image) }
        }
    }

    private func verifyPhoto(_ image: UIImage) {
        phase = .verifying
        let huntTarget = target
        let minConfidence = requirements.objectHuntMinConfidence

        Task.detached(priority: .userInitiated) {
            let passes = MissionVerifiers.photoContainsHuntObject(
                image,
                target: huntTarget,
                minConfidence: minConfidence
            )
            await MainActor.run {
                guard !didFinish else { return }
                if passes {
                    didFinish = true
                    camera.stop()
                    onComplete()
                } else {
                    phase = .rejected
                }
            }
        }
    }
}
#endif
