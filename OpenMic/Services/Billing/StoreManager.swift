import Foundation
import StoreKit

@Observable
@MainActor
final class StoreManager {
    private(set) var products: [Product] = []
    private(set) var purchasedSubscriptions: [Product] = []
    private(set) var currentTier: SubscriptionTier = .free
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored
    private var transactionListener: Task<Void, Never>?

    static let subscriptionProductIDs: Set<String> = [
        "openmic.standard.monthly",
        "openmic.premium.monthly",
    ]

    static let creditProductIDs: Set<String> = [
        "openmic.credits.50standard",
        "openmic.credits.100standard",
        "openmic.credits.50premium",
        "openmic.credits.100premium",
    ]

    static var allProductIDs: Set<String> {
        subscriptionProductIDs.union(creditProductIDs)
    }

    init() {
        transactionListener = nil
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        do {
            products = try await Product.products(for: Self.allProductIDs)
                .sorted { $0.price < $1.price }
            await updateCurrentEntitlements()
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCurrentEntitlements()
            await transaction.finish()
            return transaction

        case .userCancelled:
            return nil

        case .pending:
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        try? await AppStore.sync()
        await updateCurrentEntitlements()
        isLoading = false
    }

    // MARK: - Entitlement Check

    func updateCurrentEntitlements() async {
        var activeSubs: [Product] = []

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else {
                continue
            }

            if Self.subscriptionProductIDs.contains(transaction.productID) {
                if let product = products.first(where: { $0.id == transaction.productID }) {
                    activeSubs.append(product)
                }
            }
        }

        purchasedSubscriptions = activeSubs

        // Determine tier from active subscriptions
        if activeSubs.contains(where: { $0.id == "openmic.premium.monthly" }) {
            currentTier = .premium
        } else if activeSubs.contains(where: { $0.id == "openmic.standard.monthly" }) {
            currentTier = .standard
        } else {
            currentTier = .free
        }
    }

    // MARK: - Product Helpers

    var subscriptionProducts: [Product] {
        products.filter { Self.subscriptionProductIDs.contains($0.id) }
    }

    var creditProducts: [Product] {
        products.filter { Self.creditProductIDs.contains($0.id) }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if let transaction = try? await self.checkVerified(result) {
                    await self.updateCurrentEntitlements()
                    await self.syncSubscriptionToBackend(transaction)
                    await transaction.finish()
                }
            }
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

    // MARK: - Backend Sync

    private func syncSubscriptionToBackend(_ transaction: StoreKit.Transaction) async {
        // Sync subscription state to Supabase user_subscriptions table
        do {
            try await supabase.from("user_subscriptions")
                .upsert([
                    "product_id": transaction.productID,
                    "tier": tierForProduct(transaction.productID).rawValue,
                    "status": "active",
                    "original_transaction_id": String(transaction.originalID),
                ])
                .execute()
        } catch {
            // Non-critical — will retry on next app launch
        }
    }

    private func tierForProduct(_ productID: String) -> SubscriptionTier {
        switch productID {
        case "openmic.premium.monthly": .premium
        case "openmic.standard.monthly": .standard
        default: .free
        }
    }
}

