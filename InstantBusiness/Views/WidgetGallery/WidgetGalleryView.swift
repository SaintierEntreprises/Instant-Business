import SwiftUI

struct WidgetGalleryView: View {
    /// Thèmes gratuits d'abord.
    ///
    /// L'ordre de `allCases` est celui du modèle, qui sert aussi à l'intention de
    /// configuration du widget : trois cadenas s'affichaient avant le seul thème
    /// utilisable sans abonnement. Quelqu'un qui découvre l'écran devait faire défiler
    /// pour trouver ce à quoi il a droit.
    private var galleryOrder: [WidgetTheme] {
        WidgetTheme.allCases.filter(\.isFree) + WidgetTheme.allCases.filter { !$0.isFree }
    }

    @EnvironmentObject private var store: StoreManager
    @State private var showPaywall = false

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    /// A short mindset quote keeps previews on-brand (orange) and readable at small size,
    /// instead of whichever quote happens to be first in the content file.
    private var sampleQuote: Quote {
        ContentStore.quoteOfTheDay(category: .mindset, maxLength: 80)
            ?? Quote(
                id: "sample",
                text: "Fais de chaque jour ton chef-d'œuvre.",
                author: "John Wooden",
                category: .mindset
            )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    instructions

                    section(
                        title: "Écran d'accueil",
                        subtitle: "Quatre styles, à choisir en maintenant le widget appuyé."
                    ) {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(galleryOrder, id: \.self) { theme in
                                themeCard(theme)
                            }
                        }
                    }

                    section(
                        title: "Écran de verrouillage",
                        subtitle: "Transparent, il s'adapte automatiquement à ton fond d'écran."
                    ) {
                        lockScreenPreview
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .navigationTitle("Widget")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Color.accentColor, in: Circle())
                    Text(step)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private let steps = [
        "Reste appuyé sur ton écran d'accueil jusqu'à ce que les icônes bougent.",
        "Touche le bouton + en haut, puis cherche Instant Business.",
        "Choisis la taille, ajoute-le, puis appuie longuement dessus pour changer de thème."
    ]

    private func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            content()
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
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.45), in: Circle())
                            .padding(8)
                    }
                }

                HStack(spacing: 6) {
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
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
    }

    private func miniWidgetPreview(theme: WidgetTheme) -> some View {
        let quote = sampleQuote
        let onLight = theme == .minimal

        return ZStack {
            themeBackground(theme, category: quote.category)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: quote.category.symbolName)
                        .font(.system(size: 7, weight: .bold))
                    Text(quote.category.displayName.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .tracking(0.3)
                        .lineLimit(1)
                }
                .foregroundStyle(onLight ? quote.category.tint : .white.opacity(0.8))

                Spacer(minLength: 0)

                Text(quote.text)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(onLight ? Color.primary : .white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(4)
                Text(quote.author)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(onLight ? Color.secondary : .white.opacity(0.75))
                    .lineLimit(1)
            }
            .padding(12)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
    }

    /// Mimics the lock screen: a wallpaper-like backdrop with the transparent widget on top.
    private var lockScreenPreview: some View {
        let quote = sampleQuote
        return ZStack {
            LinearGradient(
                colors: [Color(white: 0.30), Color(white: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("9:41")
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 1) {
                    Text(quote.text)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                    Text(quote.author)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .opacity(0.7)
                }
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func themeBackground(_ theme: WidgetTheme, category: QuoteCategory) -> some View {
        switch theme {
        case .bold:
            category.tint
        case .minimal:
            Color(.systemBackground)
        case .gradient:
            ZStack {
                Color.black
                LinearGradient(
                    colors: [category.tint, category.tint.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .dark:
            LinearGradient(colors: [Color(white: 0.14), .black], startPoint: .top, endPoint: .bottom)
        }
    }
}

#Preview {
    WidgetGalleryView()
        .environmentObject(StoreManager())
}
