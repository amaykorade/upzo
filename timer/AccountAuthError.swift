import Foundation
#if os(iOS)
import AuthenticationServices
#endif

enum AccountAuthError: LocalizedError {
    case noPresenter
    case missingIdentityToken
    case cancelled
    case appleSignInFailed(String)

    var errorDescription: String? {
        switch self {
        case .noPresenter:
            return "Could not present the sign-in screen."
        case .missingIdentityToken:
            return "Apple did not return a sign-in token. Try again."
        case .cancelled:
            return "Sign-in was cancelled."
        case .appleSignInFailed(let detail):
            return detail
        }
    }

    static func message(for error: Error) -> String {
        let ns = error as NSError

        #if os(iOS)
        if ns.domain == ASAuthorizationError.errorDomain,
           ns.code == ASAuthorizationError.canceled.rawValue {
            return AccountAuthError.cancelled.errorDescription!
        }
        #endif

        if ns.domain == "AKAuthenticationError" && ns.code == -7026 {
            if !SignInEntitlementDiagnostics.buildConfigurationHint.isEmpty {
                return SignInEntitlementDiagnostics.buildConfigurationHint
            }
            return "Sign in with Apple could not start. Open Settings → Apple Account, confirm you are signed in, then try again."
        }

        #if os(iOS)
        if ns.domain == ASAuthorizationError.errorDomain,
           ns.code == ASAuthorizationError.unknown.rawValue {
            if !SignInEntitlementDiagnostics.buildConfigurationHint.isEmpty {
                return SignInEntitlementDiagnostics.buildConfigurationHint
            }
            if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError,
               underlying.domain == "AKAuthenticationError", underlying.code == -7026 {
                return "Sign in with Apple could not start. Open Settings → Apple Account, confirm you are signed in, then try again."
            }
            return "Sign in with Apple could not start. Open Settings → Apple Account, confirm you are signed in, then try again."
        }
        #endif

        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return localized
        }
        return error.localizedDescription
    }
}
