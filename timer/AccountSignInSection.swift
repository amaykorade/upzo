#if os(iOS)
import SwiftUI

/// Sign-in for Account settings (Sign in with Apple).
struct AccountSignInSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sign in with Apple. Your account is stored on this device until we add cloud sync.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SignInWithAppleControl(buttonHeight: 50)
        }
    }
}
#endif
