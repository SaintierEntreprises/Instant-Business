import SwiftUI

/// Liste des auteurs, filtrable. Le fil ne propose que du hasard : quelqu'un qui vient de
/// lire une citation de Buffett n'avait aucun moyen de voir les dix autres.
struct AuthorSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    /// Recalculé à chaque frappe, mais seulement en filtrant un index déjà trié.
    private var results: [ContentStore.Author] {
        ContentStore.authors(matching: query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    emptyState
                } else {
                    List(results) { author in
                        NavigationLink {
                            AuthorQuotesView(author: author.name)
                        } label: {
                            row(for: author)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Auteurs")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Rechercher un auteur"
            )
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
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
            Text("Aucun auteur pour « \(query) »")
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
