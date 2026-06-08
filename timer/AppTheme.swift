import SwiftUI

/// Shared layout and styling. Sun orange is reserved for accents and highlights only.
enum AppTheme {
    static let cardCornerRadius: CGFloat = 16
    static let controlCornerRadius: CGFloat = 14
    static let rowIconWidth: CGFloat = 36
    /// Shared leading inset for tab screen titles and scroll content (apply once per screen).
    static let screenHorizontalPadding: CGFloat = 16

    static let screenTitleFont: Font = .system(size: 28, weight: .bold, design: .rounded)
    static let screenTitleLogoSize: CGFloat = 32
    static let sectionHeaderFont: Font = .subheadline.weight(.semibold)
    static let screenBlockSpacing: CGFloat = 10

    /// Bright sun orange — toggles, links, streak highlights, next-alarm emphasis.
    static let sunAccent = Color.accentColor

    /// Max content width on iPad so layouts stay readable (phone-first design).
    static let padReadableMaxWidth: CGFloat = 520

#if os(iOS)
    static var groupedScreenBackground: Color {
        Color(uiColor: .systemGroupedBackground)
    }

    static var cardFill: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
#else
    static var groupedScreenBackground: Color { .clear }
    static var cardFill: Color { Color.primary.opacity(0.06) }
#endif

    static var cardStroke: Color {
        Color.primary.opacity(0.08)
    }

#if os(iOS)
    /// Standard iOS green for switches (readable in light and dark mode).
    static var toggleTint: Color { Color(uiColor: .systemGreen) }
#else
    static var toggleTint: Color { .green }
#endif
}

struct TimerScreenTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppTheme.screenTitleFont)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(title)
    }
}

extension View {
    @ViewBuilder
    func timerScreenChrome() -> some View {
#if os(iOS)
        self.listStyle(.insetGrouped)
#else
        self
#endif
    }

    func timerScreenBackground() -> some View {
        background(AppTheme.groupedScreenBackground.ignoresSafeArea())
    }

    /// Applies the only horizontal inset for a tab screen (header + body share the same leading edge).
    func timerTabScreenInsets() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
    }

    /// Centers the phone UI on iPad with a readable max width; iPhone is unchanged.
    @ViewBuilder
    func adaptivePhoneLayoutOnPad() -> some View {
#if os(iOS)
        modifier(AdaptivePhoneLayoutOnPadModifier())
#else
        self
#endif
    }

    /// Standard neutral card. Pass `highlighted: true` for sun-tinted emphasis (e.g. next alarm).
    func timerCardBackground(highlighted: Bool = false) -> some View {
        background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(highlighted ? AppTheme.sunAccent.opacity(0.12) : AppTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(
                    highlighted ? AppTheme.sunAccent.opacity(0.45) : AppTheme.cardStroke,
                    lineWidth: highlighted ? 1.5 : 1
                )
        )
    }

    func timerListRowBackground(highlighted: Bool = false) -> some View {
        background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(highlighted ? AppTheme.sunAccent.opacity(0.12) : AppTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    highlighted ? AppTheme.sunAccent.opacity(0.45) : AppTheme.cardStroke,
                    lineWidth: 1
                )
        )
    }

    /// Next wake-up cards on Home — soft sun tint, light border, elevated shadow.
    func wakeUpCardBackground(isPrimary: Bool = false) -> some View {
        modifier(WakeUpCardBackgroundModifier(isPrimary: isPrimary))
    }
}

#if os(iOS)
private struct AdaptivePhoneLayoutOnPadModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                content.frame(maxWidth: AppTheme.padReadableMaxWidth)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.groupedScreenBackground.ignoresSafeArea())
        } else {
            content
        }
    }
}
#endif

private struct WakeUpCardBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    var isPrimary: Bool

    private var fillColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.1)
        }
        // Near-white with a hint of warmth — reads lighter than tinted orange fill.
        return Color(red: 1.0, green: 0.995, blue: 0.98)
    }

    private var borderColor: Color {
        AppTheme.sunAccent.opacity(isPrimary ? 0.16 : 0.1)
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .fill(fillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }
}
