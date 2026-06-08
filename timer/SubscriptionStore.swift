#if os(iOS)
import Combine
import Foundation
import StoreKit

@MainActor
final class SubscriptionStore: ObservableObject {
    static let shared = SubscriptionStore()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isEligibleForIntroOffer = false
    @Published var errorMessage: String?

    /// First free-trial intro period from loaded products (for paywall copy).
    var introTrialPeriod: Product.SubscriptionPeriod? {
        for product in products {
            guard let intro = product.subscription?.introductoryOffer,
                  intro.paymentMode == .freeTrial
            else { continue }
            return intro.period
        }
        return nil
    }

    var isPremium: Bool {
        hasActiveSubscription
    }

    var hasActiveSubscription: Bool {
        !purchasedProductIDs.isEmpty
    }

    var activeProduct: Product? {
        products.first { purchasedProductIDs.contains($0.id) }
    }

    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProducts.monthly }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionProducts.yearly }
    }

    /// Product shown on the paywall primary CTA (monthly when available).
    var paywallPrimaryProduct: Product? {
        monthlyProduct ?? products.first
    }

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await listenForTransactions() }
        Task { await refresh() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        await loadProducts()
        await refreshIntroOfferEligibility()
        await updatePurchasedProducts()
    }

    /// Starts the App Store purchase sheet. Returns `true` only after a verified subscription entitlement exists.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard SubscriptionProducts.all.contains(product.id) else {
            errorMessage = "Unknown subscription product."
            return false
        }
        guard !isPurchasing else { return false }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                if hasActiveSubscription {
                    return true
                }
                errorMessage = "Purchase completed but subscription is not active yet. Try Restore purchases."
                return false
            case .userCancelled:
                errorMessage = "Subscribe to unlock alarms and continue."
                return false
            case .pending:
                errorMessage = "Purchase is pending approval. You can use the app after it is approved."
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            if hasActiveSubscription {
                return true
            }
            errorMessage = "No active subscription found for this Apple ID."
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Private

    private func loadProducts() async {
        do {
            let loaded = try await Product.products(for: SubscriptionProducts.all)
            products = loaded.sorted { $0.price < $1.price }
        } catch {
            products = []
            errorMessage = "Could not load subscription options. Try again later."
        }
    }

    private func refreshIntroOfferEligibility() async {
        var eligible = false
        for product in products {
            guard let subscription = product.subscription else { continue }
            if await subscription.isEligibleForIntroOffer {
                eligible = true
                break
            }
        }
        isEligibleForIntroOffer = eligible
    }

    func introOfferSubtitle(for product: Product) async -> String? {
        guard let subscription = product.subscription,
              await subscription.isEligibleForIntroOffer,
              let intro = subscription.introductoryOffer,
              intro.paymentMode == .freeTrial
        else { return nil }

        return SubscriptionIntroOfferFormatting.freeTrialPlanSubtitle(
            introPeriod: intro.period,
            price: product.displayPrice,
            renewalPeriod: subscription.subscriptionPeriod
        )
    }

    private func updatePurchasedProducts() async {
        var active = Set<String>()
        var subscriptionStatusAvailable = false

        // Prefer subscription status (handles cancel/clear more reliably than entitlements alone).
        for product in products where SubscriptionProducts.all.contains(product.id) {
            guard let subscription = product.subscription else { continue }

            let statuses: [Product.SubscriptionInfo.Status]
            do {
                statuses = try await subscription.status
                subscriptionStatusAvailable = true
            } catch {
                continue
            }

            for status in statuses {
                switch status.state {
                case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                    if case .verified(let transaction) = status.transaction,
                       let expiration = transaction.expirationDate,
                       expiration <= Date() {
                        continue
                    }
                    active.insert(product.id)
                case .expired, .revoked:
                    break
                default:
                    break
                }
            }
        }

        // Fallback only when status API is unavailable (offline / StoreKit error).
        if !subscriptionStatusAvailable {
            for await result in Transaction.currentEntitlements {
                guard let transaction = try? checkVerified(result),
                      SubscriptionProducts.all.contains(transaction.productID),
                      transaction.revocationDate == nil
                else { continue }

                if let expiration = transaction.expirationDate, expiration <= Date() {
                    continue
                }

                active.insert(transaction.productID)
            }
        }

        purchasedProductIDs = active
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }
            await transaction.finish()
            await updatePurchasedProducts()
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
#endif
