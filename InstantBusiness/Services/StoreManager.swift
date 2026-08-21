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

    /// Premium peut venir de deux sources indépendantes : un abonnement StoreKit, ou un
    /// accès offert à la main depuis Supabase. Les deux sont suivies séparément, sinon
    /// le rafraîchissement StoreKit du retour au premier plan écraserait le cadeau.
    private var hasSubscription = false
    @Published private(set) var hasGrantedPremium = SharedDefaults.hasGrantedPremium

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
        errorMessage = nil
        do {
            products = try await Product.products(for: [Self.monthlyID, Self.yearlyID])
                .sorted { $0.price < $1.price }
            if products.isEmpty {
                errorMessage = "Les offres ne sont pas disponibles pour le moment."
            }
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

    /// Accès offert, tel que le serveur vient de le rapporter. Passer `nil` quand la
    /// requête a échoué : on garde alors la dernière valeur connue plutôt que de retirer
    /// Premium à quelqu'un simplement parce qu'il a ouvert l'app hors ligne.
    func applyGrantedPremium(_ granted: Bool?) {
        guard let granted else { return }
        hasGrantedPremium = granted
        SharedDefaults.hasGrantedPremium = granted
        publishEntitlement()
    }

    private func updateEntitlement() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.monthlyID || transaction.productID == Self.yearlyID {
                premium = true
            }
        }
        hasSubscription = premium
        publishEntitlement()
    }

    private func publishEntitlement() {
        let premium = hasSubscription || hasGrantedPremium
        isPremium = premium
        // Le widget lit cette valeur : elle doit refléter les deux sources.
        SharedDefaults.isPremium = premium
    }
}
