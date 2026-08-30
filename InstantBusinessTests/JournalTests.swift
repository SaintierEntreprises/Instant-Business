import XCTest
@testable import InstantBusiness

/// Tests du journal.
///
/// Ce qu'ils protègent ne se voit pas tout de suite : un journal faux affiche des
/// citations parfaitement valides, simplement pas celles qui ont été lues — et personne ne
/// peut s'en apercevoir sans avoir gardé une trace ailleurs.
final class JournalTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private var today: Date { calendar.startOfDay(for: Date()) }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }

    private func key(_ offset: Int) -> String {
        SharedDefaults.dayKey(for: day(offset))
    }

    func testLesJoursSontRendusDuPlusRecentAuPlusAncien() {
        let entries = Journal.entries(
            openDays: [key(0), key(-3), key(-1)],
            frozenDays: [],
            remembered: [:],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map(\.id), [key(0), key(-1), key(-3)])
    }

    /// Le cœur du sujet : ce qui a été montré prime sur ce que le catalogue donnerait
    /// aujourd'hui.
    func testUneCitationRetenuePrimeSurLeRecalcul() {
        guard let stored = ContentStore.allQuotes.last else { return XCTFail("catalogue vide") }

        let entries = Journal.entries(
            openDays: [key(-1)],
            frozenDays: [],
            remembered: [key(-1): stored.id],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(entries.first?.quote.id, stored.id)
        XCTAssertEqual(entries.first?.isRemembered, true)
    }

    /// Sans mémoire, le journal se replie sur le recalcul plutôt que de s'ouvrir vide chez
    /// quelqu'un qui tenait déjà une série avant la mise à jour.
    func testUnJourSansMemoireEstRecalcule() {
        let entries = Journal.entries(
            openDays: [key(-2)],
            frozenDays: [],
            remembered: [:],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.isRemembered, false)
        XCTAssertEqual(entries.first?.quote.id, ContentStore.quoteOfTheDay(on: day(-2))?.id)
    }

    /// Un identifiant disparu du catalogue ne doit pas faire un trou dans le journal.
    func testUnIdentifiantInconnuRetombeSurLeRecalcul() {
        let entries = Journal.entries(
            openDays: [key(-1)],
            frozenDays: [],
            remembered: [key(-1): "q-inexistante"],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.isRemembered, false)
    }

    func testUnJourGeleFigureAuJournalEtEstSignale() {
        let entries = Journal.entries(
            openDays: [key(0)],
            frozenDays: [key(-1)],
            remembered: [:],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first { $0.id == key(-1) }?.isFrozen, true)
        XCTAssertEqual(entries.first { $0.id == key(0) }?.isFrozen, false)
    }

    /// Une horloge reculée depuis laisserait des clés futures dans l'historique.
    func testUnJourFuturEstIgnore() {
        let entries = Journal.entries(
            openDays: [key(0), key(3)],
            frozenDays: [],
            remembered: [:],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(entries.map(\.id), [key(0)])
    }

    func testLesClesIllisiblesSontIgnorees() {
        let entries = Journal.entries(
            openDays: ["pas-une-date", key(0)],
            frozenDays: [],
            remembered: [:],
            calendar: calendar,
            today: today
        )

        XCTAssertEqual(entries.map(\.id), [key(0)])
    }

    // MARK: - Mémoire

    func testLaPremiereCitationRetenueNEstJamaisEcrasee() {
        let saved = SharedDefaults.dailyQuoteIDs
        defer { SharedDefaults.dailyQuoteIDs = saved }
        SharedDefaults.dailyQuoteIDs = [:]

        SharedDefaults.rememberDailyQuote(id: "q-premiere", on: day(0))
        SharedDefaults.rememberDailyQuote(id: "q-seconde", on: day(0))

        XCTAssertEqual(SharedDefaults.dailyQuoteIDs[key(0)], "q-premiere")
    }

    func testLaCleJourFaitUnAllerRetour() {
        let roundTrip = SharedDefaults.date(fromDayKey: SharedDefaults.dayKey(for: day(-5)))
        XCTAssertNotNil(roundTrip)
        XCTAssertTrue(calendar.isDate(roundTrip!, inSameDayAs: day(-5)))
    }

    // MARK: - Libellés

    func testLesDeuxDerniersJoursSontNommes() {
        XCTAssertEqual(JournalView.dayLabel(for: today, today: today, calendar: calendar), "Aujourd'hui")
        XCTAssertEqual(JournalView.dayLabel(for: day(-1), today: today, calendar: calendar), "Hier")
        XCTAssertNotEqual(JournalView.dayLabel(for: day(-2), today: today, calendar: calendar), "Hier")
    }
}
