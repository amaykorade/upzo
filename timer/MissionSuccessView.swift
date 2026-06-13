#if os(iOS)
import SwiftUI
import UIKit

struct MissionSuccessView: View {
    let snapshot: MissionShareSnapshot
    var onFinish: () -> Void

    @State private var didFinish = false
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.96)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    AppTheme.sunAccent.opacity(0.22),
                    Color.clear,
                ],
                center: .center,
                startRadius: 40,
                endRadius: 280
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 22) {
                AppLogoView(size: 104, style: .appIcon)
                    .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                    .shadow(color: AppTheme.sunAccent.opacity(0.55), radius: 28, y: 10)

                Text("You did it!")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("with")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))

                    Text(AppBrand.name)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: AppTheme.sunAccent.opacity(0.9), radius: 14, y: 4)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(AppTheme.sunAccent.opacity(0.28))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(AppTheme.sunAccent.opacity(0.65), lineWidth: 1.5)
                                )
                        )
                }

                HStack(spacing: 10) {
                    Image(systemName: "sunrise.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.sunAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Woke up at")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(snapshot.wakeUpTime)
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.top, 4)

                Text(snapshot.celebrationMessage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                MissionShareMissionLabel(snapshot: snapshot, style: .screen)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 120)
            .allowsHitTesting(false)

            VStack {
                Spacer()
                VStack(spacing: 14) {
                    shareButton
                    cancelButton
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(2)
        .onAppear {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .sheet(isPresented: $showShareSheet, onDismiss: finishAfterShare) {
            if let shareImage {
                MissionShareSheet(image: shareImage)
            }
        }
    }

    private var shareButton: some View {
        Button(action: openShare) {
            Label("Share on social", systemImage: "square.and.arrow.up")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.black)
                .background(AppTheme.sunAccent, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share your wake-up on social media")
    }

    private var cancelButton: some View {
        Button(action: finish) {
            Text("Cancel")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white.opacity(0.88))
                .background(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss success banner")
    }

    private func openShare() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        guard let image = MissionSocialShare.renderImage(snapshot: snapshot) else { return }
        shareImage = image
        showShareSheet = true
    }

    private func finishAfterShare() {
        showShareSheet = false
        shareImage = nil
        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }
}
#endif
