#if os(iOS)
import AuthenticationServices
import SwiftUI

/// Reusable Sign in with Apple button, simulator notice, and error display.
struct SignInWithAppleControl: View {
    @EnvironmentObject private var accountStore: AccountStore
    @Environment(\.colorScheme) private var colorScheme

    var buttonHeight: CGFloat = 52

    private var entitlementWarning: String {
        SignInEntitlementDiagnostics.buildConfigurationHint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if SignInCapabilities.isSimulator {
                simulatorNotice
            } else {
                if !entitlementWarning.isEmpty {
                    entitlementNotice(entitlementWarning)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task { await accountStore.handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight)
                .disabled(accountStore.isAuthInProgress || !entitlementWarning.isEmpty)
            }

            if accountStore.isAuthInProgress {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Signing in…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if let error = accountStore.authErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            accountStore.clearAuthError()
        }
    }

    private var simulatorNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Use a physical iPhone", systemImage: "iphone")
                .font(.subheadline.weight(.semibold))
            Text("Sign in with Apple does not work in the Simulator. Select your iPhone in Xcode and run (⌘R).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func entitlementNotice(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Signing not configured", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
#endif
