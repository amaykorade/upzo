import Foundation

enum SignInCapabilities {
    /// Sign in with Apple works on a physical iPhone when the build includes the entitlement.
    static var isAppleSignInEnabled: Bool {
        #if os(iOS) && targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
