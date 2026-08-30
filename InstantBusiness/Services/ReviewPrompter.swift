import Foundation
import StoreKit
import UIKit

/// Décide quand demander une note, et le fait via la feuille native d'Apple.
///
/// La demande passe par `requestReview`, qui affiche les cinq étoiles **dans l'app** :
/// personne n'est renvoyé vers l'App Store, la note part depuis la feuille elle-même.
/// C'est la seule façon d'obtenir une note sans faire sortir la personne, et c'est aussi
/// la seule qu'Apple autorise à déclencher soi-même.
///
/// Deux limites d'Apple qu'il faut connaître, parce qu'elles conditionnent tout le reste :
/// - **On ne sait pas si quelqu'un a déjà noté.** Le système ne le dit pas. Impossible
///   donc de ne cibler que ceux qui n'ont pas noté ; on demande à qui remplit les
///   conditions, et le système ignore silencieusement la demande s'il juge qu'elle est de
///   trop.
/// - **Trois affichages par an maximum**, tous comptés par iOS. Une demande faite au
///   mauvais moment est donc définitivement perdue pour l'année. D'où les garde-fous
///   ci-dessous : ils servent à ne pas gaspiller ces trois cartouches.
enum ReviewPrompter {
    /// Jours d'ouverture distincts avant la première sollicitation.
    ///
    /// Cinq jours, pas cinq ouvertures : quelqu'un qui ouvre l'app cinq fois dans la même
    /// soirée n'a pas encore d'avis, quelqu'un qui revient cinq jours de suite en a un.
    static let minimumOpenDays = 5

    /// Délai entre deux sollicitations. Large, parce qu'on n'a que trois cartouches par an.
    static let minimumDaysBetweenPrompts = 120

    /// Aligné sur le plafond d'iOS : au-delà, la demande ne s'afficherait de toute façon
    /// pas, et on préfère ne pas la déclencher plutôt que de croire l'avoir faite.
    static let maximumPrompts = 3

    /// Règle pure, sans effet de bord, pour pouvoir être testée sur des cas limites que
    /// l'on ne peut pas reproduire à la main.
    static func shouldRequest(
        openDays: Int,
        promptCount: Int,
        lastPrompt: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard openDays >= minimumOpenDays else { return false }
        guard promptCount < maximumPrompts else { return false }
        guard let lastPrompt else { return true }

        let elapsed = calendar.dateComponents([.day], from: lastPrompt, to: now).day ?? 0
        return elapsed >= minimumDaysBetweenPrompts
    }

    /// Demande la note si le moment s'y prête. Retourne `true` si la demande a été émise.
    ///
    /// À n'appeler qu'après un moment positif — un palier de série franchi, jamais après
    /// un échec ou une erreur. Une note se demande quand on vient de donner quelque chose,
    /// pas quand on vient de décevoir.
    @MainActor
    @discardableResult
    static func requestIfAppropriate(now: Date = Date()) -> Bool {
        guard shouldRequest(
            openDays: SharedDefaults.openDays.count,
            promptCount: SharedDefaults.reviewPromptCount,
            lastPrompt: SharedDefaults.lastReviewPromptDate,
            now: now
        ) else { return false }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return false }

        SharedDefaults.reviewPromptCount += 1
        SharedDefaults.lastReviewPromptDate = now
        AppStore.requestReview(in: scene)
        return true
    }

    /// Fiche App Store ouverte directement sur le formulaire d'avis, pour la ligne
    /// « Noter l'app » des réglages.
    ///
    /// Indispensable en complément de la feuille native : celle-ci peut refuser de
    /// s'afficher sans prévenir, et quelqu'un qui veut noter doit toujours pouvoir le
    /// faire de lui-même.
    static var writeReviewURL: URL? {
        URL(string: "https://apps.apple.com/app/id\(AppUpdateGate.appStoreID)?action=write-review")
    }
}
