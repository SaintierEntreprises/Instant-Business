import XCTest
@testable import InstantBusiness

/// Tests de l'attribution de la citation du jour.
///
/// La règle est simple à énoncer — la première notification de la journée porte la
/// citation du jour — et facile à casser : la version précédente l'attribuait au premier
/// créneau du *rythme*, pas au premier créneau *programmé*. Quelqu'un qui activait les
/// notifications l'après-midi ne recevait donc jamais la citation du jour ce jour-là.
/// Ce cas ne se reproduit à la main qu'en changeant l'heure du téléphone.
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

    /// Le cas qui motivait la correction : le créneau du matin est déjà passé.
    func testSiLeMatinEstPasseLeSoirPorteLaCitationDuJour() {
        let slots = NotificationManager.slots(
            for: date(30, 12), hours: [9, 20], now: date(30, 14), calendar: calendar)
        XCTAssertEqual(slots.count, 1, "seul le créneau du soir reste programmable")
        XCTAssertEqual(slots[0].hour, 20)
        XCTAssertTrue(slots[0].carriesDailyQuote,
                      "l'unique notification de la journée doit être la citation du jour")
    }

    // MARK: - Rythmes plus denses

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
}
