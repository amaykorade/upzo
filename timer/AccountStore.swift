import Foundation
import Combine
#if os(iOS)
import AuthenticationServices
import UIKit
#endif

@MainActor
final class AccountStore: ObservableObject {
    static let shared = AccountStore()

    private enum Keys {
        static let accountID = "account.id"
        static let isSignedIn = "account.isSignedIn"
        static let displayName = "account.displayName"
        static let email = "account.email"
        static let authProvider = "account.authProvider"
        static let appleUserID = "account.appleUserID"
    }

    @Published private(set) var accountID: String
    @Published private(set) var isSignedIn: Bool
    @Published private(set) var displayName: String?
    @Published private(set) var email: String?
    @Published private(set) var authProvider: AccountAuthProvider
    @Published private(set) var authErrorMessage: String?
    @Published private(set) var isAuthInProgress = false

    private var appleUserID: String?
    /// Avoid logging out immediately after sign-in while Apple credential state catches up.
    private var lastAppleSignInAt: Date?

    private init() {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: Keys.accountID), !existing.isEmpty {
            accountID = existing
        } else {
            let id = UUID().uuidString
            defaults.set(id, forKey: Keys.accountID)
            accountID = id
        }
        isSignedIn = defaults.bool(forKey: Keys.isSignedIn)
        displayName = defaults.string(forKey: Keys.displayName)
        email = defaults.string(forKey: Keys.email)
        let providerRaw = defaults.string(forKey: Keys.authProvider) ?? AccountAuthProvider.none.rawValue
        authProvider = AccountAuthProvider(rawValue: providerRaw) ?? .none
        appleUserID = defaults.string(forKey: Keys.appleUserID)

#if os(iOS)
        Task { await restoreSessionIfPossible() }
#endif
    }

    var accountIDDisplay: String {
        accountID.uppercased()
    }

    var accountIDShort: String {
        String(accountID.prefix(8)).uppercased()
    }

    var signedInSummary: String {
        guard isSignedIn else { return "Not signed in" }
        if let displayName, !displayName.isEmpty {
            return displayName
        }
        if let email, !email.isEmpty {
            return email
        }
        return "Signed in with \(authProvider.displayName)"
    }

    func copyAccountIDToPasteboard() {
#if os(iOS)
        UIPasteboard.general.string = accountID
#endif
    }

    func clearAuthError() {
        authErrorMessage = nil
    }

#if os(iOS)
    func signInWithApple() async {
        guard !isAuthInProgress else { return }
        isAuthInProgress = true
        authErrorMessage = nil
        defer { isAuthInProgress = false }

        let hint = SignInEntitlementDiagnostics.buildConfigurationHint
        if !hint.isEmpty {
            authErrorMessage = hint
            return
        }

        do {
            let authorization = try await AppleSignInCoordinator.shared.signIn()
            await completeAppleSignIn(authorization)
        } catch {
            let ns = error as NSError
            if ns.domain == ASAuthorizationError.errorDomain,
               ns.code == ASAuthorizationError.canceled.rawValue {
                authErrorMessage = nil
            } else {
                authErrorMessage = AccountAuthError.message(for: error)
                logSignInError(ns, error)
            }
        }
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        guard !isAuthInProgress else { return }
        isAuthInProgress = true
        defer { isAuthInProgress = false }

        let hint = SignInEntitlementDiagnostics.buildConfigurationHint
        if !hint.isEmpty {
            authErrorMessage = hint
            return
        }

        authErrorMessage = nil

        switch result {
        case .success(let authorization):
            await completeAppleSignIn(authorization)
        case .failure(let error):
            let ns = error as NSError
            if ns.domain == ASAuthorizationError.errorDomain,
               ns.code == ASAuthorizationError.canceled.rawValue {
                authErrorMessage = nil
            } else {
                authErrorMessage = AccountAuthError.message(for: error)
                logSignInError(ns, error)
            }
        }
    }

    private func logSignInError(_ ns: NSError, _ error: Error) {
        #if DEBUG
        print("[SignInWithApple] \(ns.domain) code=\(ns.code) \(error.localizedDescription)")
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            print("[SignInWithApple] underlying: \(underlying.domain) code=\(underlying.code)")
        }
        #endif
    }

    private func completeAppleSignIn(_ authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            authErrorMessage = AccountAuthError.missingIdentityToken.localizedDescription
            return
        }

        let userID = credential.user
        appleUserID = userID

        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let resolvedName = name.isEmpty ? displayName : name
        let resolvedEmail = credential.email ?? email

        lastAppleSignInAt = Date()

        applySignedInSession(
            accountID: userID,
            provider: .apple,
            displayName: resolvedName,
            email: resolvedEmail
        )

        UserDefaults.standard.set(userID, forKey: Keys.appleUserID)
    }

    private func restoreSessionIfPossible() async {
        authErrorMessage = nil

        switch authProvider {
        case .apple:
            guard let appleUserID else {
                if isSignedIn { logout() }
                return
            }

            // Right after Sign in with Apple, credential state can briefly report .notFound.
            if let lastAppleSignInAt,
               Date().timeIntervalSince(lastAppleSignInAt) < 120 {
                isSignedIn = true
                return
            }

            let state = await AppleSignInCoordinator.shared.credentialState(for: appleUserID)
            switch state {
            case .authorized:
                isSignedIn = true
            case .revoked:
                logout()
            case .notFound:
                // Keep local session; .notFound is often transient (network / Apple ID re-auth).
                break
            case .transferred:
                break
            @unknown default:
                break
            }
        case .google:
            if isSignedIn { logout() }
        case .none:
            break
        }
    }
#endif

    func logout() {
        isSignedIn = false
        displayName = nil
        email = nil
        authProvider = .none
        appleUserID = nil
        lastAppleSignInAt = nil
        authErrorMessage = nil

        UserDefaults.standard.set(false, forKey: Keys.isSignedIn)
        UserDefaults.standard.removeObject(forKey: Keys.displayName)
        UserDefaults.standard.removeObject(forKey: Keys.email)
        UserDefaults.standard.set(AccountAuthProvider.none.rawValue, forKey: Keys.authProvider)
        UserDefaults.standard.removeObject(forKey: Keys.appleUserID)
    }

    func deleteAccount() {
#if os(iOS)
        Task { await CloudKitUserDataSync.shared.deleteRemoteBackup() }
#endif
        logout()
        let newID = UUID().uuidString
        accountID = newID
        UserDefaults.standard.set(newID, forKey: Keys.accountID)
    }

    private func applySignedInSession(
        accountID: String,
        provider: AccountAuthProvider,
        displayName: String?,
        email: String?
    ) {
        self.accountID = accountID
        self.authProvider = provider
        self.isSignedIn = true
        self.displayName = displayName
        self.email = email
        self.authErrorMessage = nil

        let defaults = UserDefaults.standard
        defaults.set(accountID, forKey: Keys.accountID)
        defaults.set(true, forKey: Keys.isSignedIn)
        defaults.set(provider.rawValue, forKey: Keys.authProvider)
        if let displayName, !displayName.isEmpty {
            defaults.set(displayName, forKey: Keys.displayName)
        } else {
            defaults.removeObject(forKey: Keys.displayName)
        }
        if let email, !email.isEmpty {
            defaults.set(email, forKey: Keys.email)
        } else {
            defaults.removeObject(forKey: Keys.email)
        }
    }
}
