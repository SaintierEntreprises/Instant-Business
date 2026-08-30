import SwiftUI

/// Recherche : les auteurs, et le texte des citations.
///
/// Le fil ne propose que du hasard, et l'écran ne cherchait que par auteur : avec 573
/// citations, quelqu'un qui se rappelait d'une phrase sur l'échec sans savoir qui l'avait
/// dite n'avait aucun moyen de la retrouver. Les deux résultats cohabitent dans une même
/// liste, auteurs d'abord — c'est la recherche la plus fréquente, et la plus courte à
/// parcourir.
struct AuthorSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var detailQuote: Quote?

    /// Recalculé à chaque frappe, mais seulement en filtrant un index déjà trié.
    private var authorResults: [ContentStore.Author] {
        ContentStore.authors(matching: query)
    }

    /// Vide tant que rien n'est saisi : afficher les 573 citations d'entrée ferait de cet
    /// écran une liste à faire défiler, alors qu'il sert à trouver.
    private var quoteResults: [Quote] {
        ContentStore.quotes(matching: query)
    }

    private var isEmpty: Bool {
        authorResults.isEmpty && quoteResults.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    emptyState
                } else {
                    List {
                        if !authorResults.isEmpty {
                            Section("Auteurs") {
                                ForEach(authorResults) { author in
                                    NavigationLink {
                                        AuthorQuotesView(author: author.name)
                                    } label: {
                                        row(for: author)
                                    }
                                }
                            }
                        }

                        if !quoteResults.isEmpty {
                            Section("Citations") {
                                ForEach(quoteResults) { quote in
                                    Button {
                                        Haptics.tap()
                                        detailQuote = quote
                                    } label: {
                                        row(for: quote)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Rechercher")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Un auteur, un mot, une phrase"
            )
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .sheet(item: $detailQuote) { quote in
                QuoteDetailView(quote: quote)
            }
            // Une seule mesure par recherche aboutie, et jamais la saisie elle-même :
            // ce qui est tapé dans un champ de recherche est du texte personnel.
            .onChange(of: quoteResults.count) { _, count in
                guard count > 0, query.count >= 3 else { return }
                Analytics.track(.quoteSearched, ["results": .int(count)])
            }
        }
    }

    private func row(for quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(quote.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Circle()
                    .fill(quote.category.tint)
                    .frame(width: 6, height: 6)
                Text(quote.author)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func row(for author: ContentStore.Author) -> some View {
        HStack(spacing: 14) {
            // Initiales plutôt qu'un portrait : aucune image d'auteur n'est embarquée, et
            // une pastille vide serait pire que pas de pastille.
            Text(initials(for: author.name))
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12), in: Circle())

            Text(author.name)
                .font(.body.weight(.medium))

            Spacer(minLength: 8)

            Text("\(author.quoteCount)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text(query.isEmpty
                 ? "Cherche un auteur, un mot ou une phrase"
                 : "Aucun résultat pour « \(query) »")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func initials(for name: String) -> String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}

#Preview {
    AuthorSearchView()
}
