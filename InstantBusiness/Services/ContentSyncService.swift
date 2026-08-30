import Foundation
import WidgetKit

/// Récupère les citations depuis Supabase et remplace le contenu local.
///
/// Le contenu était figé dans le bundle : corriger une attribution ou ajouter dix
/// citations demandait une soumission App Store complète, review comprise. Il vient
/// désormais du serveur, avec le JSON embarqué comme secours — au premier lancement, hors
/// ligne, et à chaque fois que la réponse n'est pas crédible.
///
/// Volontairement silencieux en cas d'échec : ne pas réussir à rafraîchir n'est pas une
/// panne, c'est l'état normal d'une app sans réseau. Elle a déjà tout ce qu'il lui faut.
@MainActor
enum ContentSyncService {
    /// Intervalle minimal entre deux vérifications.
    ///
    /// Le contenu bouge quelques fois par an. Interroger le serveur à chaque passage au
    /// premier plan coûterait une requête par ouverture pour ne rien apprendre —
    /// et l'app en fait déjà plusieurs au démarrage.
    private static let refreshInterval: TimeInterval = 6 * 3600

    private struct RemoteQuote: Decodable {
        let id: String
        let text: String
        let author: String
        let category: String
        let context: String?
        let source: String?
        let year: Int?
    }

    static func refreshIfNeeded(force: Bool = false) async {
        if !force,
           let last = SharedDefaults.lastContentSyncDate,
           Date().timeIntervalSince(last) < refreshInterval {
            return
        }

        do {
            let rows: [RemoteQuote] = try await SupabaseProvider.client
                .from("quotes")
                .select("id,text,author,category,context,source,year")
                .execute()
                .value

            // Une catégorie inconnue signifie que le serveur connaît une rubrique que
            // cette version de l'app ne sait pas afficher : on ignore ces lignes plutôt
            // que d'abandonner tout le rafraîchissement. C'est ce qui permettra
            // d'introduire une catégorie sans casser les versions déjà installées.
            let quotes: [Quote] = rows.compactMap { row in
                guard let category = QuoteCategory(rawValue: row.category) else { return nil }
                return Quote(
                    id: row.id,
                    text: row.text,
                    author: row.author,
                    category: category,
                    context: row.context,
                    source: row.source,
                    year: row.year
                )
            }

            guard ContentStore.apply(remoteQuotes: quotes) else { return }

            // La date n'est écrite qu'après une application réussie : un contenu refusé
            // par le plancher de confiance doit être retenté à la prochaine ouverture,
            // pas dans six heures.
            SharedDefaults.lastContentSyncDate = Date()

            // Le widget garde en mémoire une timeline construite sur l'ancien contenu :
            // sans ce rechargement, il continuerait d'afficher une citation qui vient
            // d'être corrigée, voire supprimée.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Hors ligne, ou table absente : le contenu embarqué prend le relais.
        }
    }
}
