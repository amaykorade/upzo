#if os(iOS)
import SwiftUI
import StoreKit

/// Shared subscription purchase UI for account settings.
struct SubscriptionPlansCard: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.openURL) private var openURL

    var showsPremiumHeader: Bool = true
    var showsManageAndLegal: Bool = true
    var emphasizeIntroOffer: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsPremiumHeader {
                if subscriptionStore.isPremium, let active = subscriptionStore.activeProduct {
                    premiumActiveCard(product: active)
                } else {
                    upgradeHeader
                }
            }

            if !subscriptionStore.isPremium {
                plansContent
            }

            if showsManageAndLegal {
                manageActions
                subscriptionLegalFooter
            }

            if let error = subscriptionStore.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var upgradeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppBrand.name)
                .font(.headline)
            Text("Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var plansContent: some View {
        if subscriptionStore.isLoading {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 8)
        } else if subscriptionStore.products.isEmpty {
            Text("Subscriptions aren’t available right now. Check your connection and try again.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(subscriptionStore.products, id: \.id) { product in
                SubscriptionProductRow(product: product, emphasizeIntroOffer: emphasizeIntroOffer)
            }
        }
    }

    private func premiumActiveCard(product: Product) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(AppBrand.name) active", systemImage: "checkmark.seal.fill")
                .font(.headline)
            Text(product.displayName)
                .font(.subheadline.weight(.semibold))
            Text(product.displayPrice)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var manageActions: some View {
        VStack(spacing: 0) {
            Button {
                Task { _ = await subscriptionStore.restorePurchases() }
            } label: {
                manageRow(title: "Restore purchases", icon: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(subscriptionStore.isPurchasing)

            Divider().padding(.leading, 52)

            Button {
                openManageSubscriptions()
            } label: {
                manageRow(title: "Manage subscription", icon: "creditcard")
            }
            .buttonStyle(.plain)
        }
        .timerCardBackground()
    }

    private func manageRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var subscriptionLegalFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment is charged to your Apple ID. Manage or cancel in Settings → Apple ID → Subscriptions.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let url = SettingsLinks.termsOfServiceURL {
                    Button("Terms of Use") { openURL(url) }
                } else {
                    NavigationLink("Terms of Use") {
                        LegalDocumentView(document: .termsOfService)
                    }
                }
                if let url = SettingsLinks.privacyPolicyURL {
                    Button("Privacy Policy") { openURL(url) }
                } else {
                    NavigationLink("Privacy Policy") {
                        LegalDocumentView(document: .privacyPolicy)
                    }
                }
            }
            .font(.caption2)
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }

    private func openManageSubscriptions() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
        else { return }

        Task {
            try? await AppStore.showManageSubscriptions(in: scene)
        }
    }
}

private struct SubscriptionProductRow: View {
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    let product: Product
    let emphasizeIntroOffer: Bool

    @State private var introSubtitle: String?

    var body: some View {
        Button {
            Task { await subscriptionStore.purchase(product) }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let introSubtitle, emphasizeIntroOffer {
                        Text(introSubtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.sunAccent)
                    } else {
                        Text(subscriptionPeriodLabel(product))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.body.weight(.bold))
                        .foregroundStyle(.primary)
                    if introSubtitle != nil, emphasizeIntroOffer {
                        Text("then billed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(subscriptionStore.isPurchasing)
        .task(id: product.id) {
            introSubtitle = await subscriptionStore.introOfferSubtitle(for: product)
        }
    }

    private func subscriptionPeriodLabel(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return product.description
        }
        switch period.unit {
        case .month: return "Renews monthly"
        case .year: return "Renews yearly"
        case .week: return "Renews weekly"
        case .day: return "Renews daily"
        @unknown default: return "Auto-renewing"
        }
    }
}
#endif
