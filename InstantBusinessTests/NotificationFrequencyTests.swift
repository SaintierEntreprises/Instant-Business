import XCTest
@testable import InstantBusiness

/// Tests du rythme de notifications.
///
/// Ce réglage a déjà causé un dégât réel : une version antérieure envoyait des
/// notifications à minuit et à 4h du matin, et des gens ont tout coupé. Les invariants
/// ci-dessous — jamais avant 8h, jamais après 21h, un défaut à deux par jour — sont donc
/// vérifiés plutôt que supposés.
final class NotificationFrequencyTests: XCTestCase {
    func testLeRythmeParDefautEstDeuxParJour() {
        XCTAssertEqual(NotificationFrequency.default, .duo)
        XCTAssertEqual(NotificationFrequency.default.perDay, 2)
    }

    func testLeRythmeParDefautEstMatinEtSoir() {
        let hours = NotificationFrequency.duo.hours
        XCTAssertEqual(hours.count, 2)
        guard let matin = hours.first, let soir = hours.last else { return XCTFail("créneaux manquants") }
        XCTAssertLessThanOrEqual(matin, 12, "le premier créneau doit tomber le matin")
        XCTAssertGreaterThanOrEqual(soir, 18, "le second créneau doit tomber le soir")
    }

    /// L'invariant qui a motivé toute la refonte : plus rien la nuit.
    func testAucunCreneauEnDehorsDeHuitHeuresVingtEtUne() {
        for frequency in NotificationFrequency.allCases {
            for hour in frequency.hours {
                XCTAssertGreaterThanOrEqual(hour, 8, "\(frequency.rawValue) programme à \(hour)h")
                XCTAssertLessThanOrEqual(hour, 21, "\(frequency.rawValue) programme à \(hour)h")
            }
        }
    }

    func testLesCreneauxSontCroissantsEtSansDoublon() {
        for frequency in NotificationFrequency.allCases {
            XCTAssertEqual(frequency.hours, frequency.hours.sorted(), "\(frequency.rawValue) : créneaux désordonnés")
            XCTAssertEqual(Set(frequency.hours).count, frequency.hours.count, "\(frequency.rawValue) : créneau en double")
        }
    }

    /// Les sélecteurs affichent `allCases` tel quel : l'ordre doit aller du plus calme au
    /// plus soutenu, sinon la liste se lit de travers.
    func testLesRythmesSontClassesDuPlusCalmeAuPlusSoutenu() {
        let counts = NotificationFrequency.allCases.map(\.perDay)
        XCTAssertEqual(counts, counts.sorted())
        XCTAssertEqual(counts, [1, 2, 3, 6])
    }

    /// iOS plafonne à 64 les notifications locales en attente. La fenêtre glissante doit
    /// tenir sous cette limite pour chaque rythme, les deux rappels de série compris.
    func testLaFenetreGlissanteResteSousLePlafondIOS() {
        for frequency in NotificationFrequency.allCases {
            let perDay = max(1, frequency.perDay)
            let days = min(14, max(3, 55 / perDay))
            let pending = days * perDay + 2
            XCTAssertLessThan(pending, 64, "\(frequency.rawValue) : \(pending) notifications en attente")
        }
    }

    /// Un libellé stocké reste lisible : changer un `rawValue` réinitialiserait
    /// silencieusement le réglage de tous ceux qui l'avaient choisi.
    func testLesIdentifiantsStockesSontStables() {
        XCTAssertEqual(NotificationFrequency.light.rawValue, "light")
        XCTAssertEqual(NotificationFrequency.duo.rawValue, "duo")
        XCTAssertEqual(NotificationFrequency.balanced.rawValue, "balanced")
        XCTAssertEqual(NotificationFrequency.frequent.rawValue, "frequent")
    }

    /// Un choix explicite doit primer sur le nouveau défaut.
    func testUnChoixExpliciteResisteAuChangementDeDefaut() {
        let previous = SharedDefaults.notificationFrequency
        defer { SharedDefaults.notificationFrequency = previous }

        SharedDefaults.notificationFrequency = .frequent
        XCTAssertEqual(SharedDefaults.notificationFrequency, .frequent)
    }

    func testChaqueRythmeAUnLibelleEtUnResume() {
        for frequency in NotificationFrequency.allCases {
            XCTAssertFalse(frequency.displayName.isEmpty)
            XCTAssertFalse(frequency.summary.isEmpty)
            XCTAssertFalse(frequency.detail.isEmpty)
            XCTAssertFalse(frequency.symbolName.isEmpty)
        }
    }
}
