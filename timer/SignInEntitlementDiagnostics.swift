#if os(iOS)
import Foundation

/// Runtime check for Sign in with Apple in **debug** builds only.
/// App Store / TestFlight installs have no `embedded.mobileprovision` and must not be blocked by a heuristic scan.
enum SignInEntitlementDiagnostics {
    private static let entitlementKey = "com.apple.developer.applesignin"

    /// Whether this install appears to include the Sign in with Apple entitlement (debug/ad-hoc only).
    static var isSignedWithAppleSignIn: Bool {
        #if DEBUG
        #if targetEnvironment(simulator)
        return false
        #else
        if provisioningProfileContainsEntitlement { return true }
        return executableContainsEntitlement
        #endif
        #else
        return true
        #endif
    }

    /// Shown in the sign-in UI when the current build is misconfigured. Empty in Release and when entitled.
    static var buildConfigurationHint: String {
        #if DEBUG
        if SignInCapabilities.isSimulator {
            return "Sign in with Apple only works on a physical iPhone. Choose your iPhone as the run destination in Xcode, then Run (⌘R)."
        }
        if isSignedWithAppleSignIn {
            return ""
        }
        return """
        This build is missing the Sign in with Apple entitlement (the app was signed without it).

        Fix in Xcode (one time):
        1. timer target → Signing & Capabilities → keep the “Sign in with Apple” card if it appears (do not delete it).
        2. Build Settings → Code Signing Entitlements (Any iOS SDK) → timer/timer.entitlements.
        3. developer.apple.com → App ID com.amay.timer → enable Sign in with Apple → Save.
        4. Delete the app on your iPhone, Clean Build Folder, Run to your iPhone.
        """
        #else
        return ""
        #endif
    }

    #if DEBUG
    private static var provisioningProfileContainsEntitlement: Bool {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else {
            return false
        }
        return data.contains(entitlementKey.utf8)
    }

    private static var executableContainsEntitlement: Bool {
        guard let url = Bundle.main.executableURL,
              let data = try? Data(contentsOf: url) else {
            return false
        }
        return data.contains(entitlementKey.utf8)
    }
    #endif
}
#endif
