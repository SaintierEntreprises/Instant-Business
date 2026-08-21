import UIKit

/// Générateurs conservés et réamorcés après chaque usage.
///
/// Les instancier au moment du tap, comme le faisait le code précédent, coûte un retard
/// perceptible sur le premier retour : le moteur haptique doit sortir de veille, et
/// `prepare()` n'a alors pas eu le temps d'agir. Les garder chauds rend le retour
/// simultané au visuel, condition pour qu'il soit perçu comme la même sensation
/// plutôt que comme deux évènements distincts.
@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// À appeler à l'apparition d'un écran interactif, pas au moment du tap.
    static func prepare() {
        light.prepare()
        medium.prepare()
        selection.prepare()
    }

    /// Choix d'une option parmi plusieurs, passage d'une carte à la suivante.
    static func select() {
        selection.selectionChanged()
        selection.prepare()
    }

    /// Commande secondaire : partage, retrait d'un favori.
    static func tap() {
        light.impactOccurred()
        light.prepare()
    }

    /// Action principale d'un écran : valider, continuer, ajouter aux favoris.
    static func commit() {
        medium.impactOccurred()
        medium.prepare()
    }

    /// Aboutissement d'un parcours. Réservé aux moments qui le méritent — un retour
    /// haptique partout entraîne à les ignorer tous.
    static func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }
}
