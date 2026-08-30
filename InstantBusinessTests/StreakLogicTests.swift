import XCTest
@testable import InstantBusiness

/// Tests de la règle de série.
///
/// C'est la seule partie de l'app dont un bug est invisible : elle dépend du calendrier,
/// donc une erreur ne se manifeste ni au clic ni à la compilation, mais trois semaines
/// plus tard chez quelqu'un qui perd une série qu'il avait tenue. Les cas couverts ici
/// sont exactement ceux qu'on ne peut pas reproduire à la main sans changer l'heure du
/// téléphone.
final class StreakLogicTests: XCTestCase {
    private var calendar: Calendar { StreakWeek.calendar }
    private var today: Date { calendar.startOfDay(for: Date()) }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today)!
    }

    /// Date fixe pour tout ce qui touche à la semaine affichée : un dimanche, donc le
    /// dernier jour de sa semaine, où les jours précédents figurent tous.
    ///
    /// Ces tests s'appuyaient sur la date du jour et devenaient faux le lundi — « hier »
    /// tombait alors dans la semaine précédente, la recherche ne renvoyait rien, et trois
    /// assertions échouaient sans que rien n'ait changé dans l'app. Un test de calendrier
    /// ne doit pas dépendre du jour où on le lance.
    private var weekReference: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 30))!
    }

    private func weekDay(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: weekReference)!
    }

    override func setUp() {
        super.setUp()
        // Chaque test repart d'un état vierge : ces valeurs vivent dans la suite partagée
        // du groupe d'app, elles survivraient sinon d'un test à l'autre.
        SharedDefaults.streakCount = 0
        SharedDefaults.bestStreak = 0
        SharedDefaults.openDays = []
        SharedDefaults.frozenDays = []
        SharedDefaults.freezesRemaining = 0
        SharedDefaults.freezeGranted = 0
        SharedDefaults.freezePeriod = nil
        SharedDefaults.lastFreezeDate = nil
        SharedDefaults.celebratedMilestone = 0
        SharedDefaults.isPremium = false
    }

    // MARK: - Règle de base

    func testOuvertureLeMemeJourNeChangeRien() {
        let result = StreakManager.resolve(daysSince: 0, previousStreak: 5, today: today, isPremium: false)
        XCTAssertEqual(result.streak, 5)
        XCTAssertNil(result.frozenDay)
    }

    func testLendemainIncremente() {
        let result = StreakManager.resolve(daysSince: 1, previousStreak: 5, today: today, isPremium: false)
        XCTAssertEqual(result.streak, 6)
        XCTAssertNil(result.frozenDay)
    }

    /// Une série à 0 qui reprend doit valoir 1, pas 0 : `max(previousStreak, 1)` couvre le
    /// compte tout neuf dont la ligne serveur existe déjà avec `streak_count = 0`.
    func testMemeJourAvecSerieAZeroDonneUn() {
        let result = StreakManager.resolve(daysSince: 0, previousStreak: 0, today: today, isPremium: false)
        XCTAssertEqual(result.streak, 1)
    }

    func testTroisJoursManquesRemettentAUn() {
        SharedDefaults.freezesRemaining = 3
        SharedDefaults.freezeGranted = 3
        SharedDefaults.freezePeriod = StreakFreeze.period(for: today)

        let result = StreakManager.resolve(daysSince: 4, previousStreak: 30, today: today, isPremium: true)
        XCTAssertEqual(result.streak, 1)
        XCTAssertNil(result.frozenDay)
        // Le joker ne couvre qu'une journée : il ne doit pas être dépensé pour rien.
        XCTAssertEqual(SharedDefaults.freezesRemaining, 3)
    }

    // MARK: - Jokers

    func testUneJourneeManqueeConsommeUnJokerEtGardeLaSerie() {
        SharedDefaults.freezePeriod = StreakFreeze.period(for: today)
        SharedDefaults.freezeGranted = 1
        SharedDefaults.freezesRemaining = 1

        let result = StreakManager.resolve(daysSince: 2, previousStreak: 9, today: today, isPremium: false)

        XCTAssertEqual(result.streak, 10)
        XCTAssertEqual(result.frozenDay, day(-1))
        XCTAssertEqual(SharedDefaults.freezesRemaining, 0)
        XCTAssertTrue(SharedDefaults.frozenDays.contains(SharedDefaults.dayKey(for: day(-1))))
    }

    func testSansJokerUneJourneeManqueeCasseLaSerie() {
        SharedDefaults.freezePeriod = StreakFreeze.period(for: today)
        SharedDefaults.freezeGranted = 1
        SharedDefaults.freezesRemaining = 0

        let result = StreakManager.resolve(daysSince: 2, previousStreak: 9, today: today, isPremium: false)

        XCTAssertEqual(result.streak, 1)
        XCTAssertNil(result.frozenDay)
        XCTAssertTrue(SharedDefaults.frozenDays.isEmpty)
    }

    /// Le bug le plus coûteux qu'on puisse écrire ici : un complément premium rejoué à
    /// chaque appel rechargerait les jokers indéfiniment, et la série deviendrait
    /// impossible à perdre.
    func testLeComplementPremiumNeSeRejouePas() {
        SharedDefaults.freezePeriod = StreakFreeze.period(for: today)
        SharedDefaults.freezeGranted = 1
        SharedDefaults.freezesRemaining = 1

        StreakFreeze.refillIfNeeded(isPremium: true, on: today)
        XCTAssertEqual(SharedDefaults.freezesRemaining, 3)

        for _ in 0..<5 {
            StreakFreeze.refillIfNeeded(isPremium: true, on: today)
        }
        XCTAssertEqual(SharedDefaults.freezesRemaining, 3)
    }

    func testLeQuotaSeRenouvelleAuChangementDeMois() {
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: today)!
        SharedDefaults.freezePeriod = StreakFreeze.period(for: lastMonth)
        SharedDefaults.freezeGranted = 1
        SharedDefaults.freezesRemaining = 0

        StreakFreeze.refillIfNeeded(isPremium: false, on: today)

        XCTAssertEqual(SharedDefaults.freezesRemaining, 1)
        XCTAssertEqual(SharedDefaults.freezePeriod, StreakFreeze.period(for: today))
    }

    /// Un abonnement qui expire ne reprend pas un joker déjà accordé pour le mois en cours.
    func testFinDAbonnementNeRetirePasLesJokersDuMois() {
        SharedDefaults.freezePeriod = StreakFreeze.period(for: today)
        SharedDefaults.freezeGranted = 3
        SharedDefaults.freezesRemaining = 3

        StreakFreeze.refillIfNeeded(isPremium: false, on: today)

        XCTAssertEqual(SharedDefaults.freezesRemaining, 3)
    }

    // MARK: - Paliers

    func testLaRuptureDeSerieRemetLesPaliersAFeter() {
        SharedDefaults.celebratedMilestone = 30

        _ = StreakManager.resolve(daysSince: 5, previousStreak: 30, today: today, isPremium: false)

        XCTAssertEqual(SharedDefaults.celebratedMilestone, 0)
    }

    func testProgressionVersLePalierSuivant() {
        let progress = StreakMilestone.progress(streak: 5)
        XCTAssertEqual(progress?.next, 7)
        XCTAssertEqual(progress?.remaining, 2)
        // La barre repart du palier précédent (3), pas de zéro : 2 jours faits sur 4.
        XCTAssertEqual(progress?.fraction ?? 0, 0.5, accuracy: 0.001)
    }

    func testAucunPalierRestantAuDelaDuDernier() {
        XCTAssertNil(StreakMilestone.progress(streak: 400))
        XCTAssertNil(StreakMilestone.next(after: 400))
    }

    // MARK: - Semaine affichée

    func testLaSemaineCommenceLundi() {
        let days = StreakWeek.days(streak: 0, openDays: [])
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first?.initial, "L")
        XCTAssertEqual(days.last?.initial, "D")
    }

    func testUnJourGeleCompteDansLaSerieSansEtreOuvert() {
        let open: Set<String> = [
            SharedDefaults.dayKey(for: weekReference),
            SharedDefaults.dayKey(for: weekDay(-2))
        ]
        let frozen: Set<String> = [SharedDefaults.dayKey(for: weekDay(-1))]

        let days = StreakWeek.days(
            streak: 3,
            openDays: open,
            frozenDays: frozen,
            reference: weekReference
        )
        let yesterday = days.first { calendar.isDate($0.date, inSameDayAs: weekDay(-1)) }

        XCTAssertNotNil(yesterday, "la veille de la référence doit figurer dans la semaine")
        XCTAssertEqual(yesterday?.isFrozen, true)
        XCTAssertEqual(yesterday?.isOpened, false)
        XCTAssertEqual(yesterday?.isInCurrentStreak, true)
    }

    /// Un jour ouvert avant une coupure reste marqué, mais hors série : l'effacer serait
    /// faux, le compter dans la série le serait aussi.
    func testUnJourOuvertAvantUneCoupureEstHorsSerie() {
        let open: Set<String> = [
            SharedDefaults.dayKey(for: weekReference),
            SharedDefaults.dayKey(for: weekDay(-1)),
            SharedDefaults.dayKey(for: weekDay(-4))
        ]

        let days = StreakWeek.days(streak: 2, openDays: open, reference: weekReference)
        let old = days.first { calendar.isDate($0.date, inSameDayAs: weekDay(-4)) }

        // La référence fixe garantit que le jour -4 figure dans la semaine. Le test
        // n'avait auparavant de valeur que certains jours, et passait sans rien vérifier
        // les autres.
        XCTAssertNotNil(old, "le jour -4 doit figurer dans la semaine")
        XCTAssertEqual(old?.isOpened, true)
        XCTAssertEqual(old?.isInCurrentStreak, false)
    }

    // MARK: - Historique reconstitué

    func testLeRemplissageRetroactifSauteLesJoursGeles() {
        SharedDefaults.frozenDays = [SharedDefaults.dayKey(for: day(-1))]

        StreakManager.recordVisit(streak: 4, on: today, calendar: calendar)

        let open = SharedDefaults.openDays
        XCTAssertTrue(open.contains(SharedDefaults.dayKey(for: today)))
        XCTAssertFalse(open.contains(SharedDefaults.dayKey(for: day(-1))), "un jour gelé n'a pas été ouvert")
        XCTAssertTrue(open.contains(SharedDefaults.dayKey(for: day(-2))))
        XCTAssertTrue(open.contains(SharedDefaults.dayKey(for: day(-3))))
    }

    func testLeRecordSuitLaMeilleureSerie() {
        StreakManager.recordVisit(streak: 12, on: today, calendar: calendar)
        XCTAssertEqual(SharedDefaults.bestStreak, 12)

        StreakManager.recordVisit(streak: 3, on: today, calendar: calendar)
        XCTAssertEqual(SharedDefaults.bestStreak, 12, "le record ne redescend jamais")
    }
}
