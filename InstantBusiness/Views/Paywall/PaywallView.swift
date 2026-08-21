import SwiftUI
import StoreKit

struct PaywallView: View {
    /// D'où l'écran a été ouvert : la barre de catégories, une page auteur, les
    /// réglages… C'est cette information qui dira lequel de ces points d'entrée
    /// convertit réellement.
    var origin: String = "unknown"

    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID: String?
    @State private var legalDocument: LegalDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 76, height: 76)
                                .shadow(color: .orange.opacity(0.35), radius: 20, y: 10)
                            Image(systemName: "crown.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                        Text("Instant Business Premium")
                            .font(.title2.weight(.bold))
                        Text("Débloque tout le potentiel de l'app")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    VStack(spacing: 14) {
                        benefitRow(icon: "square.grid.2x2.fill", color: .indigo, title: "Toutes les catégories", subtitle: "Vente, Leadership, Finance")
                        benefitRow(icon: "paintpalette.fill", color: .pink, title: "Tous les thèmes de widget", subtitle: "Bold, Minimal, Sombre…")
                        benefitRow(icon: "rectangle.stack.fill", color: .teal, title: "Tous les thèmes de cartes", subtitle: "Crème, Noir, Nuit…")
                    }
                    .padding(.horizontal)

                    if store.isLoading {
                        ProgressView()
                            .padding(.vertical, 20)
                    } else if store.products.isEmpty {
                        VStack(spacing: 12) {
                            Text(store.errorMessage ?? "Les offres ne sont pas disponibles pour le moment.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Réessayer") {
                                Task { await store.refresh() }
                            }
                            .font(.footnote.weight(.semibold))
                        }
                        .padding(.vertical, 20)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.products) { product in
                                productCard(product)
                            }
                        }
                        .padding(.horizontal)

                        Button {
                            guard let product = store.products.first(where: { $0.id == selectedProductID }) ?? store.products.first else { return }
                            Analytics.track(.purchaseStarted, [
                                "product": .string(product.id),
                                "origin": .string(origin)
                            ])
                            Task { await store.purchase(product) }
                        } label: {
                            Text("Continuer")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.97))
                        .padding(.horizontal)
                    }

                    Button("Restaurer mes achats") {
                        Task { await store.restore() }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                    VStack(spacing: 6) {
                        Text("Abonnement à renouvellement automatique, résiliable à tout moment depuis les réglages de ton compte Apple.")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        // Apple requires functional links to both the Terms of Use (EULA)
                        // and the privacy policy inside the purchase flow.
                        HStack(spacing: 6) {
                            Button("Conditions d'utilisation") { legalDocument = .termsOfUse }
                            Text("·")
                            Button("CGV") { legalDocument = .termsOfSale }
                            Text("·")
                            Button("Confidentialité") { legalDocument = .privacyPolicy }
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                    if let errorMessage = store.errorMessage, !store.products.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        Analytics.track(.paywallDismissed, ["origin": .string(origin)])
                        dismiss()
                    }
                }
            }
            .onChange(of: store.isPremium) { _, isPremium in
                if isPremium {
                    Analytics.track(.purchaseCompleted, ["origin": .string(origin)])
                    dismiss()
                }
            }
            .task {
                Analytics.track(.paywallShown, ["origin": .string(origin)])
                await store.refresh()
                if selectedProductID == nil {
                    selectedProductID = store.products.last?.id ?? store.products.first?.id
                }
            }
            .sheet(item: $legalDocument) { document in
                NavigationStack {
                    LegalDocumentView(document: document)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fermer") { legalDocument = nil }
                            }
                        }
                }
            }
        }
    }

    private func benefitRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.gradient)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    /// Spells out the renewal period next to the price, so the purchase flow states the
    /// subscription length explicitly rather than leaving it implied by the product name.
    private func periodLabel(for product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else { return nil }
        switch period.unit {
        case .day: return period.value == 1 ? "par jour" : "tous les \(period.value) jours"
        case .week: return period.value == 1 ? "par semaine" : "toutes les \(period.value) semaines"
        case .month: return period.value == 1 ? "par mois" : "tous les \(period.value) mois"
        case .year: return period.value == 1 ? "par an" : "tous les \(period.value) ans"
        @unknown default: return nil
        }
    }

    private func productCard(_ product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isYearly = product.id == StoreManager.yearlyID

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedProductID = product.id
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName).font(.headline)
                        if isYearly {
                            Text("MEILLEUR PRIX")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // The billed amount stays the most prominent element; the period is
                // deliberately subordinate (guideline 3.1.2(c)).
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice).font(.headline)
                    if let period = periodLabel(for: product) {
                        Text(period)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .foregroundStyle(.primary)
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
}
