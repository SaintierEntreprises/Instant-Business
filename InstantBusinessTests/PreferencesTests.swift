import XCTest
@testable import InstantBusiness

/// Tests des réglages restaurés depuis le serveur.
///
/// Une restauration ratée ne plante pas : elle remet silencieusement des valeurs par
/// défaut. Quelqu'un réglé sur deux citations par jour en reçoit trois et met des semaines
/// à s'en apercevoir — si tant est qu'il fasse le lien avec sa réinstallation.
final class PreferencesTests: XCTestCase {
    private typealias Preferences = UserSyncService.Preferences

    /// Un compte créé avant ces colonnes ne dit rien de ses réglages. Écraser le local par
    /// des valeurs par défaut serait pire que de ne rien restaurer.
    func testDesPreferencesVidesSontReconnues() {
        XCTAssertTrue(Preferences().isEmpty)
        XCTAssertFalse(Preferences(notificationFrequency: .duo).isEmpty)
        XCTAssertFalse(Preferences(notificationsEnabled: false).isEmpty)
        XCTAssertFalse(Preferences(appTheme: .dark).isEmpty)
        XCTAssertFalse(Preferences(cardTheme: .couleur).isEmpty)
    }

    /// `notificationsEnabled: false` est une information, pas une absence : quelqu'un qui a
    /// coupé ses notifications ne doit pas se les voir rallumer.
    func testUnRefusExpliciteNEstPasUneAbsence() {
        XCTAssertFalse(Preferences(notificationsEnabled: false).isEmpty)
    }

    // MARK: - Aller-retour des valeurs stockées

    func testChaqueRythmeSurvitALEcritureEtALaRelecture() {
        for frequency in NotificationFrequency.allCases {
            XCTAssertEqual(
                NotificationFrequency(rawValue: frequency.rawValue),
                frequency,
                "rythme \(frequency.rawValue) illisible après un aller-retour"
            )
        }
    }

    func testChaqueThemeDAppSurvitALAllerRetour() {
        for theme in AppTheme.allCases {
            XCTAssertEqual(AppTheme(rawValue: theme.rawValue), theme)
        }
    }

    func testChaqueThemeDeCarteSurvitALAllerRetour() {
        for theme in CardTheme.allCases {
            XCTAssertEqual(CardTheme(rawValue: theme.rawValue), theme)
        }
    }

    /// Une valeur ajoutée par une version plus récente ne doit pas être interprétée de
    /// travers : mieux vaut ignorer le réglage que d'en appliquer un autre.
    func testUneValeurInconnueEstIgnoree() {
        XCTAssertNil(NotificationFrequency(rawValue: "toutes-les-heures"))
        XCTAssertNil(AppTheme(rawValue: "sepia"))
        XCTAssertNil(CardTheme(rawValue: "neon"))
    }

    // MARK: - Persistance locale

    func testLeRythmeEcritEstReluTelQuel() {
        let saved = SharedDefaults.notificationFrequency
        defer { SharedDefaults.notificationFrequency = saved }

        for frequency in NotificationFrequency.allCases {
            SharedDefaults.notificationFrequency = frequency
            XCTAssertEqual(SharedDefaults.notificationFrequency, frequency)
        }
    }

    /// Le garde-fou qui rend tout le reste utile : ces réglages ne doivent pas figurer
    /// dans l'effacement de compte, sinon changer de compte les reperdrait quand même.
    func testLesReglagesDUsageSurviventALEffacementDeCompte() {
        let savedFrequency = SharedDefaults.notificationFrequency
        let savedTheme = SharedDefaults.appTheme
        let savedEnabled = SharedDefaults.notificationsEnabled
        defer {
            SharedDefaults.notificationFrequency = savedFrequency
            SharedDefaults.appTheme = savedTheme
            SharedDefaults.notificationsEnabled = savedEnabled
        }

        SharedDefaults.notificationFrequency = .frequent
        SharedDefaults.appTheme = .dark
        SharedDefaults.notificationsEnabled = true

        SharedDefaults.resetAccountData()

        XCTAssertEqual(SharedDefaults.notificationFrequency, .frequent)
        XCTAssertEqual(SharedDefaults.appTheme, .dark)
        XCTAssertTrue(SharedDefaults.notificationsEnabled)
    }
}
