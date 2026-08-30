import XCTest
@testable import InstantBusiness

/// Tests de l'estampille de version posée sur le contenu téléchargé.
///
/// Le bug qu'ils protègent est silencieux : l'app affiche des citations parfaitement
/// valides, simplement amputées des champs que la version installée sait désormais
/// montrer. Rien ne plante, rien n'est vide, et seul un œil qui connaît le contenu
/// attendu peut s'en apercevoir.
final class ContentCacheStampTests: XCTestCase {
    private var savedStamp: String?

    override func setUp() {
        super.setUp()
        savedStamp = SharedDefaults.cachedContentBuild
    }

    override func tearDown() {
        SharedDefaults.cachedContentBuild = savedStamp
        super.tearDown()
    }

    func testLaVersionCouranteEstRenseignee() {
        let build = SharedDefaults.currentAppBuild
        XCTAssertFalse(build.contains("?"), "version illisible : \(build)")
        XCTAssertTrue(build.contains("("), "format attendu « 1.2 (31) », reçu \(build)")
    }

    func testAppliquerUnContenuDistantPoseLEstampille() {
        SharedDefaults.cachedContentBuild = "0.1 (1)"

        let applied = ContentStore.apply(remoteQuotes: ContentStore.allQuotes)

        XCTAssertTrue(applied, "le catalogue complet doit passer le plancher de confiance")
        XCTAssertEqual(SharedDefaults.cachedContentBuild, SharedDefaults.currentAppBuild)
    }

    func testUnContenuRefuseNeTouchePasALEstampille() {
        SharedDefaults.cachedContentBuild = "0.1 (1)"

        let applied = ContentStore.apply(remoteQuotes: Array(ContentStore.allQuotes.prefix(3)))

        XCTAssertFalse(applied)
        XCTAssertEqual(
            SharedDefaults.cachedContentBuild,
            "0.1 (1)",
            "un contenu rejeté ne doit pas faire croire que le cache est à jour"
        )
    }

    /// Le contenu embarqué est le filet de sécurité quand le cache est écarté : il doit
    /// porter les champs que cette version sait afficher, sans quoi écarter le cache ne
    /// servirait à rien.
    func testLeContenuEmbarquePorteLesExplications() {
        let quotes = ContentStore.allQuotes
        let withMeaning = quotes.filter { $0.meaning?.isEmpty == false }
        let withApplication = quotes.filter { $0.application?.isEmpty == false }

        XCTAssertEqual(withMeaning.count, quotes.count, "citations sans principe")
        XCTAssertEqual(withApplication.count, quotes.count, "citations sans mise en application")
    }
}
