import XCTest
@testable import InstantBusiness

/// Tests de l'attribution de la citation du jour.
///
/// La règle : le premier créneau du rythme choisi porte la citation du jour, les autres
/// une citation de rotation. Elle doit surtout être **stable** — `reschedule()` reconstruit
/// toutes les notifications à chaque passage au premier plan, et une attribution qui
/// dépendrait de l'heure d'exécution enverrait la même citation plusieurs fois par jour.
/// C'est exactement ce qui s'est produit quand elle visait « le premier créneau encore à
/// venir ». Ce cas ne se reproduit à la main qu'en changeant l'heure du téléphone.
final class NotificationSlotTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        return c
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }

    // MARK: - Un seul créneau

    func testUnSeulCreneauPorteToujoursLaCitationDuJour() {
        let slots = NotificationManager.slots(
            for: date(30, 12), hours: [9], now: date(30, 6), calendar: calendar)
        XCTAssertEqual(slots.count, 1)
        XCTAssertTrue(slots[0].carriesDailyQuote)
    }

    // MARK: - Deux créneaux

    func testAvecDeuxCreneauxLeMatinPorteLaCitationDuJour() {
        let slots = NotificationManager.slots(
            for: date(30, 12), hours: [9, 20], now: date(30, 6), calendar: calendar)
        XCTAssertEqual(slots.count, 2)
        XCTAssertTrue(slots[0].carriesDailyQuote, "9 h doit porter la citation du jour")
        XCTAssertFalse(slots[1].carriesDailyQuote)
        XCTAssertEqual(slots[0].hour, 9)
    }

    /// Le matin passé, le soir reste une citation de rotation.
    ///
    /// Le contraire paraît plus généreux — l'unique notification restante porterait la
    /// citation du jour — mais rend l'attribution dépendante de l'heure : chaque
    /// reprogrammation la déplacerait sur le créneau suivant, et la même citation
    /// arriverait à 9 h, 14 h puis 20 h.
    func testSiLeMatinEstPasseLeSoirNePorteToujoursPasLaCitationDuJour() {
        let slots = NotificationManager.slots(
            for: date(30, 12), hours: [9, 20], now: date(30, 14), calendar: calendar)
        XCTAssertEqual(slots.count, 1, "seul le créneau du soir reste programmable")
        XCTAssertEqual(slots[0].hour, 20)
        XCTAssertFalse(slots[0].carriesDailyQuote,
                       "le soir n'est pas le premier créneau du rythme")
    }

    /// Le garde-fou contre la régression : reprogrammer plusieurs fois dans la journée ne
    /// doit jamais déplacer la citation du jour d'un créneau à l'autre.
    func testLAttributionNeDependPasDeLHeureDeReprogrammation() {
        let hours = [9, 14, 20]
        var porteurs: [Int] = []

        for heure in [6, 10, 15, 19] {
            let slots = NotificationManager.slots(
                for: date(30, 12), hours: hours, now: date(30, heure), calendar: calendar)
            porteurs.append(contentsOf: slots.filter(\.carriesDailyQuote).map(\.hour))
        }

        XCTAssertEqual(
            Set(porteurs), [9],
            "seul 9 h peut porter la citation du jour, quelle que soit l'heure de reprogrammation"
        )
    }

    /// Une journée entamée ne doit pas reprogrammer une citation du jour déjà délivrée.
    func testApresLePremierCreneauPlusAucuneCitationDuJour() {
        let slots = NotificationManager.slots(
            for: date(30, 12), hours: [9, 14, 20], now: date(30, 11), calendar: calendar)
        XCTAssertEqual(slots.map(\.hour), [14, 20])
        XCTAssertTrue(slots.allSatisfy { !$0.carriesDailyQuote })
    }

    // MARK: - Rythmes plus denses

    /// Sur une journée entière devant soi, chaque rythme désigne exactement un porteur.
    func testLaCitationDuJourEstUniqueParJournee() {
        for hours in [[9], [9, 20], [9, 14, 20], [8, 10, 13, 16, 19, 21]] {
            let slots = NotificationManager.slots(
                for: date(30, 12), hours: hours, now: date(30, 6), calendar: calendar)
            let daily = slots.filter(\.carriesDailyQuote)
            XCTAssertEqual(daily.count, 1, "rythme \(hours) : une seule citation du jour attendue")
        }
    }

    func testAucunCreneauQuandToutEstPasse() {
        let slots = NotificationManager.slots(
            for: date(30, 12), hours: [9, 20], now: date(30, 23), calendar: calendar)
        XCTAssertTrue(slots.isEmpty)
    }

    /// Sur les journées suivantes, tous les créneaux sont à venir : c'est bien le premier
    /// horaire du rythme qui porte la citation du jour.
    func testJourSuivantLePremierHoraireReprendLaCitationDuJour() {
        let slots = NotificationManager.slots(
            for: date(31, 12), hours: [8, 10, 13, 16, 19, 21], now: date(30, 14), calendar: calendar)
        XCTAssertEqual(slots.count, 6)
        XCTAssertEqual(slots[0].hour, 8)
        XCTAssertTrue(slots[0].carriesDailyQuote)
        XCTAssertFalse(slots.dropFirst().contains { $0.carriesDailyQuote })
    }

    /// Les créneaux sont triés, même si le rythme les déclarait dans le désordre.
    func testLesCreneauxSontRendusDansLOrdreChronologique() {
        let slots = NotificationManager.slots(
            for: date(30, 12), hours: [20, 9, 14], now: date(30, 6), calendar: calendar)
        XCTAssertEqual(slots.map(\.hour), [9, 14, 20])
        XCTAssertTrue(slots[0].carriesDailyQuote)
    }

    /// Chaque rythme proposé dans l'app doit produire au moins une citation du jour
    /// lorsqu'on planifie une journée entière.
    func testChaqueRythmeProduitUneCitationDuJour() {
        for frequency in NotificationFrequency.allCases {
            let slots = NotificationManager.slots(
                for: date(31, 12), hours: frequency.hours, now: date(30, 23), calendar: calendar)
            XCTAssertEqual(slots.filter(\.carriesDailyQuote).count, 1,
                           "\(frequency.rawValue) doit porter une citation du jour")
        }
    }

    // MARK: - Citations distinctes dans la journée

    /// Deux notifications d'une même journée ne doivent jamais porter la même citation.
    /// La rotation dérive de l'heure absolue : c'est ce qui garantit la distinction, et
    /// c'est aussi ce qui casserait en silence si l'unité devenait journalière.
    func testLesCitationsDeRotationDUneJourneeSontToutesDifferentes() {
        let seed = 4_242
        for hours in [[9, 20], [9, 14, 20], [8, 10, 13, 16, 19, 21]] {
            let slots = NotificationManager.slots(
                for: date(30, 12), hours: hours, now: date(30, 6), calendar: calendar)

            let identifiants = slots
                .filter { !$0.carriesDailyQuote }
                .compactMap {
                    ContentStore.rotatingQuote(
                        seed: seed,
                        unit: ContentStore.rotationUnit(for: $0.fireDate)
                    )?.id
                }

            XCTAssertEqual(
                Set(identifiants).count, identifiants.count,
                "rythme \(hours) : deux notifications portent la même citation"
            )
        }
    }

    /// Rythme désactivé : `reschedule` ne programme rien, rappel de série compris.
    func testAucunCreneauSansHoraire() {
        let slots = NotificationManager.slots(
            for: date(30, 12), hours: [], now: date(30, 6), calendar: calendar)
        XCTAssertTrue(slots.isEmpty)
    }
}
