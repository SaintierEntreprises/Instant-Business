import Foundation

struct Quote: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let author: String
    let category: QuoteCategory

    /// Une phrase de contexte : les circonstances, ce que la citation répondait, ce
    /// qu'elle a changé.
    ///
    /// Facultative, et elle le restera : elle demande une vérification pour chaque
    /// citation, et une app à moitié documentée vaut mieux qu'une app documentée au
    /// hasard. Tout ce qui l'affiche doit donc rester présentable sans elle.
    var context: String?

    /// Provenance vérifiable : discours, livre, entretien. Sert autant à l'affichage
    /// qu'à se défendre d'une attribution douteuse.
    var source: String?

    var year: Int?

    /// Vrai dès qu'il y a quelque chose à montrer en plus de la citation elle-même.
    var hasContext: Bool {
        context?.isEmpty == false || source?.isEmpty == false || year != nil
    }

    /// Ligne de provenance compacte : « Stanford, 2005 », « 2005 », ou rien.
    var provenance: String? {
        let parts = [source?.isEmpty == false ? source : nil, year.map(String.init)]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
