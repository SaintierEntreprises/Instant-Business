import Foundation

/// Réglages de notification pilotables depuis le serveur.
///
/// La programmation des notifications est calendaire : elle ne se reproduit à la main
/// qu'en changeant l'heure du téléphone, et ses défauts n'apparaissent que chez les
/// utilisateurs. Un correctif y demande un build, une revue Apple et une adoption qui
/// prend des jours. Ces trois boutons permettent d'éteindre un symptôme en attendant.
///
/// La portée est volontairement étroite : un réglage à distance ne tourne que des boutons
/// que le code sait déjà tourner. Ce n'est pas un moyen de corriger n'importe quel bug,
/// c'est un équipement posé là où l'on sait que c'est fragile.
struct NotificationConfig: Equatable {
    /// `nil` = le serveur n'a pas d'opinion, le comportement compilé s'applique.
    var isEnabled: Bool?
    var dailyQuoteMode: DailyQuoteMode?
    /// Horaires par rythme, indexés sur `NotificationFrequency.rawValue`.
    var hoursByFrequency: [String: [Int]]

    enum DailyQuoteMode: String {
        /// La citation du jour va au premier créneau du rythme.
        case first
        /// Aucun créneau ne la porte : tout devient citation de rotation.
        case off
    }

    static let empty = NotificationConfig(isEnabled: nil, dailyQuoteMode: nil, hoursByFrequency: [:])

    // MARK: - Lecture des valeurs distantes

    /// Construit une configuration à partir de valeurs brutes, en écartant tout ce qui
    /// n'est pas exploitable.
    ///
    /// La validation n'est pas de la prudence de principe : ces valeurs sont saisies à la
    /// main dans un éditeur SQL, souvent dans l'urgence d'un incident. Une faute de frappe
    /// ne doit jamais pouvoir priver tout le monde de notifications — le repli est
    /// toujours le comportement compilé.
    static func from(
        enabled: Bool?,
        dailyQuoteMode: String?,
        hours: [String: [Int]]?
    ) -> NotificationConfig {
        var validated: [String: [Int]] = [:]
        for (frequency, values) in hours ?? [:] {
            // Un rythme inconnu viendrait d'une version plus récente : l'ignorer vaut
            // mieux que d'appliquer ses horaires à un rythme qui n'est pas le sien.
            guard NotificationFrequency(rawValue: frequency) != nil else { continue }
            let cleaned = Array(Set(values.filter { (0...23).contains($0) })).sorted()
            // Une liste vide couperait les notifications de ce rythme sans le dire :
            // c'est le rôle de `notifications_enabled`, pas celui d'un horaire.
            guard !cleaned.isEmpty, cleaned.count <= maxSlotsPerDay else { continue }
            validated[frequency] = cleaned
        }

        return NotificationConfig(
            isEnabled: enabled,
            dailyQuoteMode: dailyQuoteMode.flatMap(DailyQuoteMode.init(rawValue:)),
            hoursByFrequency: validated
        )
    }

    /// Au-delà, ce ne sont plus des notifications mais du harcèlement — et une valeur
    /// aberrante saisie par erreur ne doit pas pouvoir produire ça.
    static let maxSlotsPerDay = 8

    // MARK: - Application

    /// Horaires à utiliser pour un rythme, réglage distant compris.
    func hours(for frequency: NotificationFrequency) -> [Int] {
        hoursByFrequency[frequency.rawValue] ?? frequency.hours
    }

    /// Faux uniquement si le serveur l'a explicitement demandé.
    var allowsScheduling: Bool { isEnabled != false }

    var usesDailyQuote: Bool { dailyQuoteMode != .off }
}
