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
    /// False until the first `refresh()` finishes — avoids flashing the paywall before StoreKit responds.
    @Published private(set) var hasFinishedInitialEntitlementCheck = false
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

    /// Active paid plan, or cancelled but still inside the current billing period.
    var hasActiveSubscription: Bool {
        if !purchasedProductIDs.isEmpty { return true }
        return SubscriptionAccessCache.hasValidAccess
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
        defer {
            isLoading = false
            hasFinishedInitialEntitlementCheck = true
        }

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
        var furthestExpiration: Date?

        func markActive(productID: String, expiration: Date?) {
            active.insert(productID)
            guard let expiration, expiration > Date() else { return }
            furthestExpiration = max(furthestExpiration ?? expiration, expiration)
        }

        for product in products where SubscriptionProducts.all.contains(product.id) {
            guard let subscription = product.subscription else { continue }

            let statuses: [Product.SubscriptionInfo.Status]
            do {
                statuses = try await subscription.status
            } catch {
                continue
            }

            for status in statuses {
                guard grantsAccess(for: status) else { continue }
                let expiration = expirationDate(from: status)
                markActive(productID: product.id, expiration: expiration)
            }
        }

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  SubscriptionProducts.all.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  !isExpired(transaction.expirationDate)
            else { continue }

            markActive(productID: transaction.productID, expiration: transaction.expirationDate)
        }

        // Cancelled auto-renew can drop entitlements early; history still has the paid-through date.
        if active.isEmpty {
            for await result in Transaction.all {
                guard let transaction = try? checkVerified(result),
                      SubscriptionProducts.all.contains(transaction.productID),
                      transaction.revocationDate == nil,
                      let expiration = transaction.expirationDate,
                      expiration > Date()
                else { continue }

                markActive(productID: transaction.productID, expiration: expiration)
            }
        }

        purchasedProductIDs = active

        if let furthestExpiration {
            SubscriptionAccessCache.save(accessUntil: furthestExpiration)
        } else if !SubscriptionAccessCache.hasValidAccess {
            SubscriptionAccessCache.clear()
        }
    }

    /// Cancelled plans stay `.subscribed` until Apple marks the period expired.
    private func grantsAccess(for status: Product.SubscriptionInfo.Status) -> Bool {
        switch status.state {
        case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
            return !isExpired(expirationDate(from: status))
        case .expired, .revoked:
            return false
        default:
            return false
        }
    }

    private func expirationDate(from status: Product.SubscriptionInfo.Status) -> Date? {
        if case .verified(let transaction) = status.transaction {
            return transaction.expirationDate
        }
        return nil
    }

    private func isExpired(_ expiration: Date?) -> Bool {
        guard let expiration else { return false }
        return expiration <= Date()
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
