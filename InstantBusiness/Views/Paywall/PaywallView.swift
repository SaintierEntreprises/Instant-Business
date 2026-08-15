import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        Text("Instant Business Premium")
                            .font(.title2.weight(.bold))
                        Text("Débloque toutes les catégories, tous les thèmes de widget et les notifications personnalisées.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 14) {
                        benefitRow(icon: "square.grid.2x2.fill", text: "Toutes les catégories (Vente, Leadership, Finance)")
                        benefitRow(icon: "paintpalette.fill", text: "Tous les thèmes de widget")
                        benefitRow(icon: "bell.badge.fill", text: "Heure de notification personnalisée")
                    }
                    .padding(.horizontal)

                    if store.products.isEmpty {
                        ProgressView()
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.products) { product in
                                Button {
                                    Task { await store.purchase(product) }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(product.displayName)
                                                .font(.headline)
                                            Text(product.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .font(.headline)
                                    }
                                    .padding()
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.primary)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Button("Restaurer mes achats") {
                        Task { await store.restore() }
                    }
                    .font(.footnote)
                    .padding(.top, 4)

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
            .task { await store.refresh() }
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
}
