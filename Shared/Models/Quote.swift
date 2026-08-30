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

    /// Le principe derrière la formule : ce que l'auteur veut réellement dire.
    ///
    /// Distinct de `context`, et c'est la distinction qui permet d'en avoir partout.
    /// `context` est un fait — qui, quand, à quel propos — qui se vérifie ou ne s'écrit
    /// pas. `meaning` est une lecture de la citation elle-même : elle s'appuie sur le
    /// texte, pas sur une archive. Une citation dont on ignore tout de l'origine peut
    /// donc quand même être expliquée.
    var meaning: String?

    /// Ce qu'on en fait concrètement. C'est la moitié qui justifie d'ouvrir la fiche :
    /// une citation bien expliquée mais inapplicable reste une décoration.
    var application: String?

    /// Vrai dès qu'il y a quelque chose à montrer en plus de la citation elle-même.
    var hasContext: Bool {
        context?.isEmpty == false || source?.isEmpty == false || year != nil
            || meaning?.isEmpty == false || application?.isEmpty == false
    }

    /// Ligne de provenance compacte : « Stanford, 2005 », « 2005 », ou rien.
    var provenance: String? {
        let parts = [source?.isEmpty == false ? source : nil, year.map(String.init)]
            .compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
