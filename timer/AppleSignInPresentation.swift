#if os(iOS)
import AuthenticationServices
import UIKit

enum AppleSignInPresentation {
    /// Window for `ASAuthorizationController` — must be the main app window, not a sheet's.
    @MainActor
    static func anchor() -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }

        let normalWindows = scenes
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .flatMap(\.windows)
            .filter { $0.windowLevel == .normal }

        if let key = normalWindows.first(where: \.isKeyWindow) {
            return key
        }

        if let rootHost = normalWindows.first(where: { $0.rootViewController != nil }) {
            return rootHost
        }

        if let any = normalWindows.first {
            return any
        }

        // iPad / scene transitions: any window from a connected scene is better than crashing.
        let fallbackWindows = scenes.flatMap(\.windows).filter { $0.windowLevel == .normal }
        if let any = fallbackWindows.first(where: { $0.rootViewController != nil }) ?? fallbackWindows.first {
            return any
        }

        return UIWindow()
    }

    @MainActor
    static func topViewController() -> UIViewController? {
        guard let root = anchor().rootViewController else { return nil }
        return Self.topMost(from: root)
    }

    @MainActor
    private static func topMost(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return topMost(from: presented)
        }
        if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(from: visible)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(from: selected)
        }
        return root
    }
}
#endif
