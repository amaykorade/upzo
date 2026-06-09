#if os(iOS)
import SwiftUI
import StoreKit

/// Mandatory subscription screen after sign-in. Users must complete an App Store subscription
/// before alarms unlock. Billed amount is shown most prominently per App Store Guideline 3.1.2(c).
struct SubscriptionPaywallView: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @ObservedObject private var onboardingStore = OnboardingStore.shared

    var onFinished: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        AppBrandHeader(logoSize: 44) {
                            Button {
                                Task { await restoreAndContinueIfActive() }
                            } label: {
                                Text("Restore")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(subscriptionStore.isPurchasing)
                        }
                        .padding(.top, 8)

                        headerBlock

                        includedWithPlusCard

                        paywallPurchaseBlock

                        if subscriptionStore.isEligibleForIntroOffer,
                           let trialPeriod = subscriptionStore.introTrialPeriod {
                            Text(SubscriptionIntroOfferFormatting.paywallTrialDisclaimer(introPeriod: trialPeriod))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        paywallLegalFooter

                        Spacer(minLength: 16)
                    }
                    .padding(.horizontal, AppTheme.screenHorizontalPadding)
                }
                .scrollIndicators(.hidden)
            }
            .timerScreenBackground()

            if subscriptionStore.isPurchasing {
                purchasingOverlay
            }
        }
        .task {
            await subscriptionStore.refresh()
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(personalizedHeadline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            Text("Subscribe with your Apple ID to unlock \(AppBrand.name). Auto-renews until cancelled.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var personalizedHeadline: String {
        if let name = onboardingStore.profile?.trimmedFirstName {
            return "\(name), subscribe to \(AppBrand.name)"
        }
        return "Subscribe to \(AppBrand.name)"
    }

    @ViewBuilder
    private var paywallPurchaseBlock: some View {
        if subscriptionStore.isLoading {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 12)
        } else if subscriptionStore.products.isEmpty {
            Text("Subscriptions aren’t available right now. Check your connection and try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if let monthly = subscriptionStore.monthlyProduct {
                    monthlyPlanCard(product: monthly)
                }

                if let yearly = subscriptionStore.yearlyProduct {
                    yearlyPlanCard(product: yearly)
                }

                if let error = subscriptionStore.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func monthlyPlanCard(product: Product) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            planPricingBlock(product: product, planLabel: "Monthly")

            Button {
                Task { await startSubscription(product: product) }
            } label: {
                Text("Subscribe")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: AppTheme.controlCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(subscriptionStore.isPurchasing)
        }
        .padding(16)
        .timerCardBackground()
    }

    private func yearlyPlanCard(product: Product) -> some View {
        Button {
            Task { await startSubscription(product: product) }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                planPricingBlock(product: product, planLabel: "Yearly")
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .timerCardBackground()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(subscriptionStore.isPurchasing)
    }

    /// Billed amount is the largest, most conspicuous element; trial copy is subordinate.
    private func planPricingBlock(product: Product, planLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let period = product.subscription?.subscriptionPeriod {
                Text(SubscriptionIntroOfferFormatting.billedAmountLabel(
                    price: product.displayPrice,
                    renewalPeriod: period
                ))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .monospacedDigit()
            } else {
                Text(product.displayPrice)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            Text("\(planLabel) · Auto-renews")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            if subscriptionStore.isEligibleForIntroOffer,
               let trialPeriod = subscriptionStore.introTrialPeriod {
                Text(SubscriptionIntroOfferFormatting.trialSubordinateNote(introPeriod: trialPeriod))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purchasingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Confirm in the App Store…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var includedWithPlusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Included with \(AppBrand.name)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            plusBenefitRow(icon: "alarm.fill", text: "Unlimited alarms with system-level ringing")
            plusBenefitRow(
                icon: "figure.walk",
                text: "All wake-up missions — shake, pushups, photo, object hunt, voice, math, steps, text, Bible, affirmations, and more"
            )
            plusBenefitRow(icon: "bell.badge.fill", text: "Backup notifications if you miss an alarm")
            plusBenefitRow(icon: "chart.bar.fill", text: "Morning insights and wake history")
            plusBenefitRow(icon: "speaker.wave.3.fill", text: "Alarm keeps ringing until your mission is done")
        }
        .padding(16)
        .timerCardBackground()
    }

    private var paywallLegalFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment is charged to your Apple ID. Manage or cancel in Settings → Apple ID → Subscriptions.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let url = SettingsLinks.termsOfServiceURL {
                    Link("Terms of Use", destination: url)
                }
                if let url = SettingsLinks.privacyPolicyURL {
                    Link("Privacy Policy", destination: url)
                }
            }
            .font(.caption2)
        }
        .padding(.horizontal, 4)
    }

    private func plusBenefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.sunAccent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func startSubscription(product: Product) async {
        let succeeded = await subscriptionStore.purchase(product)
        guard succeeded else { return }
        await subscriptionStore.refresh()
        guard subscriptionStore.hasActiveSubscription else { return }
        onFinished()
    }

    private func restoreAndContinueIfActive() async {
        guard await subscriptionStore.restorePurchases() else { return }
        await subscriptionStore.refresh()
        guard subscriptionStore.hasActiveSubscription else { return }
        onFinished()
    }
}

#Preview {
    SubscriptionPaywallView(onFinished: {})
        .environmentObject(SubscriptionStore.shared)
}
#endif
