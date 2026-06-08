import SwiftUI

/// How the brand mark is shown — match the subscription paywall (`.mark`) or large hero tiles (`.appIcon`).
enum AppLogoStyle {
    /// Orange sun artwork only — used in screen headers and the paywall top bar.
    case mark
    /// Rounded icon tile — used on welcome, permissions, and centered hero screens.
    case appIcon
}

/// In-app brand mark (`AppLogo` asset — same artwork as the App Store icon).
struct AppLogoView: View {
    var size: CGFloat = 56
    var style: AppLogoStyle = .appIcon

    private var cornerRadius: CGFloat {
        size * 0.2237
    }

    var body: some View {
        Group {
            switch style {
            case .mark:
                Image("AppLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            case .appIcon:
                Image("AppLogo")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(AppBrand.name)
    }
}

/// Logo on the leading edge with optional trailing actions (e.g. Restore on the paywall).
struct AppBrandHeader<Trailing: View>: View {
    var logoSize: CGFloat = 40
    @ViewBuilder var trailing: () -> Trailing

    init(logoSize: CGFloat = 40, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.logoSize = logoSize
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AppLogoView(size: logoSize, style: .mark)
            Spacer(minLength: 0)
            trailing()
        }
    }
}

extension AppBrandHeader where Trailing == EmptyView {
    init(logoSize: CGFloat = 40) {
        self.logoSize = logoSize
        self.trailing = { EmptyView() }
    }
}
