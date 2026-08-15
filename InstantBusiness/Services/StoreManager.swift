import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let monthlyID = "com.instantbusiness.app.premium.monthly"
    static let yearlyID = "com.instantbusiness.app.premium.yearly"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium: Bool = SharedDefaults.isPremium
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.monthlyID, Self.yearlyID])
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Impossible de charger les offres."
        }
        await updateEntitlement()
    }

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "L'achat a échoué."
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await updateEntitlement()
        } catch {
            errorMessage = "Impossible de restaurer les achats."
        }
    }

    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        await transaction.finish()
        await updateEntitlement()
    }

    private func updateEntitlement() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.monthlyID || transaction.productID == Self.yearlyID {
                premium = true
            }
        }
        isPremium = premium
        SharedDefaults.isPremium = premium
    }
}
