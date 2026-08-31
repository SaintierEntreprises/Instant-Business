import XCTest
@testable import InstantBusiness

/// Tests du réglage de notification piloté depuis le serveur.
///
/// Ces valeurs sont saisies à la main dans un éditeur SQL, en général pendant un incident.
/// La question que ces tests posent n'est donc pas « le réglage s'applique-t-il », mais
/// « une faute de frappe peut-elle priver tout le monde de notifications ». Le repli doit
/// toujours être le comportement compilé.
final class NotificationConfigTests: XCTestCase {
    private func config(
        enabled: Bool? = nil,
        mode: String? = nil,
        hours: [String: [Int]]? = nil
    ) -> NotificationConfig {
        NotificationConfig.from(enabled: enabled, dailyQuoteMode: mode, hours: hours)
    }

    // MARK: - Absence d'opinion

    func testUneTableVideNeChangeRien() {
        let c = NotificationConfig.empty
        XCTAssertTrue(c.allowsScheduling)
        XCTAssertTrue(c.usesDailyQuote)
        for frequency in NotificationFrequency.allCases {
            XCTAssertEqual(c.hours(for: frequency), frequency.hours)
        }
    }

    // MARK: - Interrupteur d'urgence

    func testLInterrupteurCoupeToutePlanification() {
        XCTAssertFalse(config(enabled: false).allowsScheduling)
        XCTAssertTrue(config(enabled: true).allowsScheduling)
        XCTAssertTrue(config(enabled: nil).allowsScheduling, "sans opinion, on programme")
    }

    // MARK: - Citation du jour

    /// Le réglage qui aurait éteint le doublon du 31 août sans attendre un build.
    func testLeModeOffRetireLaCitationDuJour() {
        XCTAssertFalse(config(mode: "off").usesDailyQuote)
        XCTAssertTrue(config(mode: "first").usesDailyQuote)
    }

    func testUnModeInconnuNeDesactiveRien() {
        XCTAssertTrue(config(mode: "aleatoire").usesDailyQuote)
        XCTAssertTrue(config(mode: "").usesDailyQuote)
    }

    // MARK: - Horaires

    func testLesHorairesDistantsRemplacentCeuxDuRythme() {
        let c = config(hours: ["duo": [7, 18]])
        XCTAssertEqual(c.hours(for: .duo), [7, 18])
        XCTAssertEqual(c.hours(for: .light), NotificationFrequency.light.hours,
                       "un rythme non mentionné garde les siens")
    }

    func testLesHorairesSontTriesEtDedoublonnes() {
        XCTAssertEqual(config(hours: ["duo": [20, 9, 20]]).hours(for: .duo), [9, 20])
    }

    func testUneHeureHorsCadranEstEcartee() {
        XCTAssertEqual(config(hours: ["duo": [9, 25, -3, 20]]).hours(for: .duo), [9, 20])
    }

    /// Une liste vide couperait les notifications sans le dire : c'est le rôle de
    /// l'interrupteur, pas celui d'un horaire.
    func testUneListeVideEstIgnoree() {
        XCTAssertEqual(config(hours: ["duo": []]).hours(for: .duo), NotificationFrequency.duo.hours)
        XCTAssertEqual(config(hours: ["duo": [99]]).hours(for: .duo), NotificationFrequency.duo.hours)
    }

    func testUneListeAberranteEstEcartee() {
        let trop = Array(0...23)
        XCTAssertEqual(config(hours: ["duo": trop]).hours(for: .duo), NotificationFrequency.duo.hours)
    }

    func testUnRythmeInconnuEstIgnore() {
        let c = config(hours: ["horaire": [9], "duo": [7]])
        XCTAssertEqual(c.hoursByFrequency, ["duo": [7]])
    }

    // MARK: - Bout en bout

    /// Le scénario d'incident complet : on éteint la citation du jour et on décale les
    /// horaires, sans toucher au reste.
    func testUnReglageDIncidentSAppliqueSansCasserLeReste() {
        let c = config(enabled: nil, mode: "off", hours: ["balanced": [8, 13, 19]])

        XCTAssertTrue(c.allowsScheduling)
        XCTAssertFalse(c.usesDailyQuote)
        XCTAssertEqual(c.hours(for: .balanced), [8, 13, 19])
        XCTAssertEqual(c.hours(for: .frequent), NotificationFrequency.frequent.hours)
    }
}
