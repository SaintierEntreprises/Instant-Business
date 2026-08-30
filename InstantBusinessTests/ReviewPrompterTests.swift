import XCTest
@testable import InstantBusiness

/// Tests de la règle de sollicitation.
///
/// iOS n'autorise que trois affichages par an et ne dit jamais si la personne a déjà
/// noté : une demande faite au mauvais moment est définitivement perdue pour l'année.
/// La règle qui décide de dépenser une de ces trois cartouches mérite donc d'être
/// vérifiée sur ses cas limites plutôt que constatée en production.
final class ReviewPrompterTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_756_000_000)

    private func days(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: now)!
    }

    func testPasDeDemandeAvantCinqJoursDUsage() {
        XCTAssertFalse(ReviewPrompter.shouldRequest(openDays: 1, promptCount: 0, lastPrompt: nil, now: now))
        XCTAssertFalse(ReviewPrompter.shouldRequest(openDays: 4, promptCount: 0, lastPrompt: nil, now: now))
    }

    func testPremiereDemandeDesCinqJours() {
        XCTAssertTrue(ReviewPrompter.shouldRequest(openDays: 5, promptCount: 0, lastPrompt: nil, now: now))
    }

    func testPasDeuxDemandesRapprochees() {
        XCTAssertFalse(ReviewPrompter.shouldRequest(
            openDays: 50, promptCount: 1, lastPrompt: days(30), now: now))
    }

    func testNouvelleDemandeApresLeDelai() {
        XCTAssertTrue(ReviewPrompter.shouldRequest(
            openDays: 50, promptCount: 1, lastPrompt: days(ReviewPrompter.minimumDaysBetweenPrompts), now: now))
    }

    /// Le plafond doit être strict : au-delà, iOS n'afficherait rien et on croirait à tort
    /// avoir sollicité la personne.
    func testLePlafondAnnuelEstRespecte() {
        XCTAssertFalse(ReviewPrompter.shouldRequest(
            openDays: 300, promptCount: ReviewPrompter.maximumPrompts, lastPrompt: days(365), now: now))
        XCTAssertFalse(ReviewPrompter.shouldRequest(
            openDays: 300, promptCount: ReviewPrompter.maximumPrompts + 1, lastPrompt: nil, now: now))
    }

    func testLeDernierCreneauResteDisponible() {
        XCTAssertTrue(ReviewPrompter.shouldRequest(
            openDays: 300, promptCount: ReviewPrompter.maximumPrompts - 1, lastPrompt: days(200), now: now))
    }

    /// Le plafond d'iOS est de trois par an : ne jamais le dépasser de notre côté.
    func testNosGardeFousTiennentDansLePlafondIOS() {
        XCTAssertLessThanOrEqual(ReviewPrompter.maximumPrompts, 3)
        XCTAssertGreaterThanOrEqual(
            ReviewPrompter.minimumDaysBetweenPrompts * (ReviewPrompter.maximumPrompts - 1),
            240,
            "trois demandes doivent s'étaler sur plus de huit mois")
    }

    func testLUrlDAvisViseLeFormulaireEtLaBonneApp() throws {
        let url = try XCTUnwrap(ReviewPrompter.writeReviewURL)
        XCTAssertTrue(url.absoluteString.contains("action=write-review"))
        XCTAssertTrue(url.absoluteString.contains(AppUpdateGate.appStoreID))
    }
}
