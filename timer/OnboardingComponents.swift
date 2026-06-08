#if os(iOS)
import SwiftUI

struct OnboardingInsightPage: View {
    let title: String
    let bodyText: String
    var footnote: String?
    var systemImage: String = "brain.head.profile"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.sunAccent.opacity(0.35), AppTheme.sunAccent.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)
                Image(systemName: systemImage)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(AppTheme.sunAccent)
                    .symbolRenderingMode(.hierarchical)
            }

            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyText)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let footnote {
                Text(footnote)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.sunAccent)
            }
        }
        .padding(.top, 8)
    }
}

struct OnboardingChatHelpPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How \(AppBrand.name) helps")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 12) {
                chatBubble(
                    isApp: false,
                    text: "I set alarms but still end up late…"
                )
                chatBubble(
                    isApp: true,
                    text: "A normal alarm only wakes your ears. You need something that wakes your body and brain."
                )
                chatBubble(
                    isApp: true,
                    text: "\(AppBrand.name) keeps ringing until you finish a quick mission — shake, walk, speak, or solve a puzzle — so you're actually up, not negotiating in bed."
                )
            }

            Text("We'll tailor your mission and strictness from your answers.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func chatBubble(isApp: Bool, text: String) -> some View {
        HStack {
            if isApp { Spacer(minLength: 24) }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(isApp ? .primary : .secondary)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isApp ? AppTheme.sunAccent.opacity(0.18) : AppTheme.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isApp ? AppTheme.sunAccent.opacity(0.35) : AppTheme.cardStroke, lineWidth: 1)
                )
            if !isApp { Spacer(minLength: 24) }
        }
    }
}

struct OnboardingMotivationPage: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .fill(AppTheme.sunAccent.opacity(0.2))
                    .frame(width: 120, height: 120)
                Image(systemName: systemImage)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(AppTheme.sunAccent)
            }

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 12)
        }
        .frame(maxWidth: .infinity)
    }
}

struct OnboardingRealisticWakePage: View {
    let wakeTimeLabel: String

    var body: some View {
        OnboardingInsightPage(
            title: "Waking at \(wakeTimeLabel) is a realistic target",
            bodyText: "You're not broken — you need a system that matches how your brain wakes up. We'll use your time as the anchor for your first alarm.",
            footnote: "Most people need more than a standard snooze button to get out of bed on time.",
            systemImage: "alarm.fill"
        )
    }
}
#endif
