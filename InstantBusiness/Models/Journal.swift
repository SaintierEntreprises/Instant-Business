import Foundation

/// Une journée du journal : la date, la citation qui y était à l'honneur, et la façon
/// dont elle a été retrouvée.
struct JournalEntry: Identifiable, Hashable {
    let date: Date
    let quote: Quote
    /// `false` quand la citation vient d'un recalcul et non de ce qui a été montré ce
    /// jour-là. Sert à ne pas présenter comme un souvenir ce qui n'est qu'une déduction.
    let isRemembered: Bool
    let isFrozen: Bool

    var id: String { SharedDefaults.dayKey(for: date) }
}

/// Reconstitue l'historique des citations du jour.
///
/// La série comptait les jours sans rien en garder : quelqu'un avec quarante jours
/// n'avait qu'un nombre à regarder. Le journal rend ces journées consultables, et donne
/// à la série une contrepartie que casser fait réellement perdre.
enum Journal {
    /// Journées à afficher, de la plus récente à la plus ancienne.
    ///
    /// Une journée n'apparaît que si l'app a été ouverte, ou si un joker a couvert le jour :
    /// le journal raconte ce qui a été vécu, pas ce que le calendrier permettait de voir.
    static func entries(
        openDays: Set<String>,
        frozenDays: Set<String>,
        remembered: [String: String],
        calendar: Calendar = .current,
        today: Date = Date()
    ) -> [JournalEntry] {
        let startOfToday = calendar.startOfDay(for: today)

        return (openDays.union(frozenDays))
            .sorted(by: >)
            .compactMap { key -> JournalEntry? in
                guard let date = SharedDefaults.date(fromDayKey: key) else { return nil }
                // Une clé postérieure à aujourd'hui viendrait d'une horloge reculée depuis :
                // l'afficher promettrait une citation que personne n'a encore pu lire.
                guard calendar.startOfDay(for: date) <= startOfToday else { return nil }

                guard let quote = resolve(dayKey: key, date: date, remembered: remembered) else {
                    return nil
                }
                return JournalEntry(
                    date: date,
                    quote: quote.quote,
                    isRemembered: quote.isRemembered,
                    isFrozen: frozenDays.contains(key)
                )
            }
    }

    /// La citation retenue si on l'a, sinon celle que le catalogue actuel donnerait.
    ///
    /// Le repli n'est pas cosmétique : il couvre les journées antérieures à cette mémoire,
    /// chez quelqu'un qui tenait déjà une série avant la mise à jour. Sans lui, son
    /// journal s'ouvrirait vide le jour où il en gagne un.
    static func resolve(
        dayKey: String,
        date: Date,
        remembered: [String: String]
    ) -> (quote: Quote, isRemembered: Bool)? {
        if let id = remembered[dayKey], let quote = ContentStore.quote(id: id) {
            return (quote, true)
        }
        return ContentStore.quoteOfTheDay(on: date).map { ($0, false) }
    }
}
