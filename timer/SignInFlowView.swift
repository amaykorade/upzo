#if os(iOS)
import SwiftUI

enum SignInFlowMode {
    /// First launch after onboarding and commitment.
    case newUser
    /// User chose "Already have an account?" or Apple session was restored.
    case returningUser
}

/// Dedicated full-screen sign-in after onboarding and commitment, or for returning users.
struct SignInFlowView: View {
    @EnvironmentObject private var accountStore: AccountStore

    var mode: SignInFlowMode = .newUser
    var onFinished: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 24)

                    AppLogoView(size: 88, style: .appIcon)

                    VStack(spacing: 10) {
                        Text(headline)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text(subheadline)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 8)

                    benefitsCard

                    SignInWithAppleControl()
                        .padding(.top, 4)

                    Text("We only receive what Apple shares (such as your name or email if you allow it). See our Privacy Policy in Settings → Legal.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
            }
            .scrollIndicators(.hidden)
        }
        .timerScreenBackground()
        .onAppear {
            if accountStore.isSignedIn {
                completeAndContinue()
            }
        }
        .onChange(of: accountStore.isSignedIn) { _, signedIn in
            if signedIn { completeAndContinue() }
        }
    }

    private var headline: String {
        switch mode {
        case .newUser:
            return "Sign in to \(AppBrand.name)"
        case .returningUser:
            return "Welcome back"
        }
    }

    private var subheadline: String {
        switch mode {
        case .newUser:
            return "Sign in with Apple to save your wake-up plan and use the app. Required to continue."
        case .returningUser:
            return "Sign in with Apple to open your account. You can restore your subscription after signing in."
        }
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow(icon: "person.crop.circle.badge.checkmark", text: "Secure sign-in with Apple — no new password")
            benefitRow(
                icon: "lock.shield.fill",
                text: mode == .returningUser
                    ? "Pick up where you left off on this device"
                    : "Your plan stays tied to this device"
            )
            benefitRow(icon: "arrow.triangle.2.circlepath", text: "Restore purchases after you sign in")
        }
        .padding(16)
        .timerCardBackground()
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.sunAccent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func completeAndContinue() {
        guard accountStore.isSignedIn else { return }
        onFinished()
    }
}

#Preview {
    SignInFlowView(onFinished: {})
        .environmentObject(AccountStore.shared)
}
#endif
