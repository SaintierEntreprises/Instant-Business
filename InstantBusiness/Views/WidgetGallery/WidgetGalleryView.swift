import SwiftUI

struct WidgetGalleryView: View {
    @EnvironmentObject private var store: StoreManager
    @State private var showPaywall = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    private var sampleQuote: Quote {
        ContentStore.allQuotes.first ?? Quote(
            id: "sample",
            text: "Le succès, c'est aller d'échec en échec sans perdre son enthousiasme.",
            author: "Winston Churchill",
            category: .mindset
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Ajoute le widget Instant Business à ton écran d'accueil ou de verrouillage, puis choisis un thème en maintenant le widget appuyé.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(WidgetTheme.allCases, id: \.self) { theme in
                            themeCard(theme)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Widget")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func themeCard(_ theme: WidgetTheme) -> some View {
        let locked = !theme.isFree && !store.isPremium
        return Button {
            if locked { showPaywall = true }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    miniWidgetPreview(theme: theme)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.4), in: Circle())
                            .padding(8)
                    }
                }

                HStack {
                    Text(theme.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if theme.isFree {
                        Text("GRATUIT")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
    }

    @ViewBuilder
    private func miniWidgetPreview(theme: WidgetTheme) -> some View {
        let quote = sampleQuote
        ZStack {
            background(for: theme, category: quote.category)

            VStack(alignment: .leading, spacing: 6) {
                if theme == .minimal {
                    Capsule()
                        .fill(quote.category.tint)
                        .frame(width: 18, height: 3)
                }
                Spacer()
                Text(quote.text)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(theme == .minimal ? Color.primary : Color.white)
                    .lineLimit(3)
                Text(quote.author)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme == .minimal ? Color.secondary : Color.white.opacity(0.75))
            }
            .padding(12)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    @ViewBuilder
    private func background(for theme: WidgetTheme, category: QuoteCategory) -> some View {
        switch theme {
        case .bold:
            category.tint
        case .minimal:
            Color(.systemBackground)
        case .gradient:
            LinearGradient(colors: [category.tint, .black.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dark:
            Color.black
        }
    }
}

#Preview {
    WidgetGalleryView()
        .environmentObject(StoreManager())
}
