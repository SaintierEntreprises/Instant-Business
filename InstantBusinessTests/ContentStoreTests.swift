import XCTest
@testable import InstantBusiness

/// Tests du contenu et de son ordonnancement.
///
/// Le plancher de confiance et l'ordre du fil décident tous les deux de ce que la personne
/// voit ; une erreur sur l'un des deux se traduit par une app vide ou une app qui se
/// répète, deux pannes qu'aucun test de compilation n'attrape.
final class ContentStoreTests: XCTestCase {
    func testLeContenuEmbarqueEstChargeable() {
        XCTAssertGreaterThan(ContentStore.allQuotes.count, 100)
        XCTAssertFalse(ContentStore.authors.isEmpty)
    }

    func testUnContenuDistantTropCourtEstRefuse() {
        let before = ContentStore.allQuotes.count
        let applied = ContentStore.apply(remoteQuotes: Array(ContentStore.allQuotes.prefix(3)))

        XCTAssertFalse(applied, "trois citations ne remplacent pas un catalogue")
        XCTAssertEqual(ContentStore.allQuotes.count, before)
    }

    func testLaRechercheTrouveParTexteEtParAuteur() {
        guard let sample = ContentStore.allQuotes.first else { return XCTFail("contenu vide") }

        let byAuthor = ContentStore.quotes(matching: sample.author)
        XCTAssertTrue(byAuthor.contains { $0.id == sample.id })

        // Un mot du milieu de la citation, pour ne pas tester un simple préfixe.
        let words = sample.text.split(separator: " ").filter { $0.count > 4 }
        if let word = words.dropFirst().first {
            let byText = ContentStore.quotes(matching: String(word))
            XCTAssertTrue(byText.contains { $0.id == sample.id })
        }
    }

    func testLaRechercheIgnoreAccentsEtCasse() {
        let accented = ContentStore.authors.first { $0.name.contains("è") || $0.name.contains("é") }
        guard let accented else { return }
        let stripped = accented.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        XCTAssertTrue(ContentStore.authors(matching: stripped).contains { $0.name == accented.name })
    }

    func testLaRechercheVideNeRenvoieAucuneCitation() {
        XCTAssertTrue(ContentStore.quotes(matching: "   ").isEmpty)
    }

    func testLeFilPlaceLesNonVuesEnPremier() {
        let pool = Array(ContentStore.allQuotes.prefix(30))
        let seen = Set(pool.prefix(20).map(\.id))

        let ordered = ContentStore.feedOrder(for: pool, seen: seen)

        XCTAssertEqual(ordered.count, pool.count, "rien ne doit disparaître du fil")
        let firstTen = ordered.prefix(10).map(\.id)
        XCTAssertTrue(firstTen.allSatisfy { !seen.contains($0) }, "les non vues passent devant")
    }

    func testToutVuRetombeSurUnSimpleMelange() {
        let pool = Array(ContentStore.allQuotes.prefix(20))
        let ordered = ContentStore.feedOrder(for: pool, seen: Set(pool.map(\.id)))
        XCTAssertEqual(Set(ordered.map(\.id)), Set(pool.map(\.id)))
    }

    func testLaCitationDuJourEstStablePourUneDateDonnee() {
        let date = Date(timeIntervalSince1970: 1_756_000_000)
        XCTAssertEqual(
            ContentStore.quoteOfTheDay(on: date)?.id,
            ContentStore.quoteOfTheDay(on: date)?.id
        )
    }

    /// La mémoïsation des ordres mélangés ne doit rien changer au résultat : c'est tout
    /// l'intérêt d'une rotation déterministe, et c'est ce qui garantit que le widget et
    /// les notifications montrent la même citation au même instant.
    func testLaRotationResteStablePourUneMemeGraine() {
        let first = ContentStore.rotatingQuote(seed: 4242, unit: 17)
        let second = ContentStore.rotatingQuote(seed: 4242, unit: 17)
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.id, second?.id)
    }

    func testLaRotationAvanceAvecLeCreneau() {
        let ids = (0..<8).compactMap { ContentStore.rotatingQuote(seed: 99, unit: $0)?.id }
        XCTAssertEqual(ids.count, 8)
        XCTAssertGreaterThan(Set(ids).count, 1, "la rotation doit bouger d'un créneau à l'autre")
    }

    func testDeuxGrainesDonnentDesRotationsDifferentes() {
        let a = (0..<12).compactMap { ContentStore.rotatingQuote(seed: 1, unit: $0)?.id }
        let b = (0..<12).compactMap { ContentStore.rotatingQuote(seed: 2, unit: $0)?.id }
        XCTAssertNotEqual(a, b, "chaque installation doit avoir sa propre rotation")
    }

    func testLaContrainteDeLongueurEstRespectee() {
        let quote = ContentStore.rotatingQuote(seed: 7, unit: 3, maxLength: 75)
        XCTAssertNotNil(quote)
        XCTAssertLessThanOrEqual(quote?.text.count ?? .max, 75)
    }

    func testLeMelangeEviteDeuxCitationsDuMemeAuteurDAffilee() {
        let ordered = ContentStore.shuffledAvoidingAdjacentAuthors(ContentStore.allQuotes)
        let adjacent = zip(ordered, ordered.dropFirst()).filter { $0.author == $1.author }
        // Un doublon reste possible en fin de liste, quand il ne reste qu'un auteur en
        // stock : on vérifie que ça reste marginal, pas que ça n'arrive jamais.
        XCTAssertLessThan(adjacent.count, ordered.count / 20)
    }
}
