import SwiftUI
import StoreKit

struct PaywallView: View {
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

                    if store.products.isEmpty {
                        ProgressView()
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

                    HStack(spacing: 6) {
                        Button("Conditions Générales de Vente") { legalDocument = .termsOfSale }
                        Text("·")
                        Button("Politique de confidentialité") { legalDocument = .privacyPolicy }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                    if let errorMessage = store.errorMessage {
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
                    Button("Fermer") { dismiss() }
                }
            }
            .onChange(of: store.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
            .task {
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
                Text(product.displayPrice).font(.headline)
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
