#if os(iOS)
import SwiftUI
import UIKit

struct MissionSuccessView: View {
    static let autoDismissSeconds: TimeInterval = 5

    let missionTitle: String
    var celebrationMessage: String?
    var onFinish: () -> Void

    @State private var didFinish = false
    @State private var autoDismissTask: Task<Void, Never>?

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

            VStack(spacing: 24) {
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

                if let celebrationMessage {
                    Text(celebrationMessage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                } else {
                    Text(missionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)
            .allowsHitTesting(false)
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
            autoDismissTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(Self.autoDismissSeconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    finish()
                }
            }
        }
        .onDisappear {
            autoDismissTask?.cancel()
            autoDismissTask = nil
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        autoDismissTask?.cancel()
        autoDismissTask = nil
        onFinish()
    }
}
#endif
