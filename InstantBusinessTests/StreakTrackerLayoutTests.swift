import XCTest
@testable import InstantBusiness

/// Tests de géométrie du tracker hebdomadaire.
///
/// Le rond était figé à 38 pt alors qu'une colonne n'en fait qu'environ 45 sur un iPhone :
/// anneau compris, le marqueur débordait de sa colonne et se faisait rogner par les angles
/// arrondis de la carte. Le défaut ne se voyait qu'à l'œil, sur un vrai téléphone, et pas
/// sur toutes les largeurs — exactement le genre de régression qu'un test attrape et
/// qu'une relecture manque.
final class StreakTrackerLayoutTests: XCTestCase {
    /// Largeurs utiles réelles, sheet et carte déduites, du plus étroit au plus large.
    /// iPhone SE 375, iPhone 15/16 393, iPhone 17 402, iPhone Pro Max 440.
    private let widths: [CGFloat] = [375 - 80, 393 - 80, 402 - 80, 440 - 80]

    private func column(_ width: CGFloat) -> CGFloat { width / 7 }

    func testLeRondEtSonAnneauTiennentDansLaColonne() {
        for size in [StreakWeekTracker.Size.prominent, .compact] {
            for width in widths {
                let col = column(width)
                let diameter = size.diameter(forColumn: col)
                // L'anneau d'aujourd'hui fait diamètre + 9.
                XCTAssertLessThanOrEqual(
                    diameter + 9, col,
                    "\(size) à \(width) pt : anneau de \(diameter + 9) pt dans une colonne de \(col)")
            }
        }
    }

    func testLeBandeauNeDepassePasSurLesBords() {
        for size in [StreakWeekTracker.Size.prominent, .compact] {
            for width in widths {
                let col = column(width)
                let diameter = size.diameter(forColumn: col)
                let height = min(diameter + 12, col - 2)
                // Le bandeau démarre au centre du premier rond, moins sa demi-hauteur.
                let leading = 0.5 * col - height / 2
                XCTAssertGreaterThanOrEqual(
                    leading, 0,
                    "\(size) à \(width) pt : le bandeau déborde de \(-leading) pt à gauche")

                // Et se termine au centre du dernier rond, plus sa demi-hauteur.
                let trailing = 6.5 * col + height / 2
                XCTAssertLessThanOrEqual(
                    trailing, width,
                    "\(size) à \(width) pt : le bandeau déborde de \(trailing - width) pt à droite")
            }
        }
    }

    /// Sur un écran large, rien ne doit grossir au-delà de la taille voulue.
    func testLeRondNeDepasseJamaisSaTailleSouhaitee() {
        for size in [StreakWeekTracker.Size.prominent, .compact] {
            XCTAssertEqual(size.diameter(forColumn: 200), size.circle)
        }
    }

    /// Et sur un écran très étroit, il reste visible plutôt que de disparaître.
    func testLeRondGardeUneTailleMinimale() {
        for size in [StreakWeekTracker.Size.prominent, .compact] {
            XCTAssertGreaterThanOrEqual(size.diameter(forColumn: 10), 18)
        }
    }

    func testLaHauteurDeRangeeEstStable() {
        // Elle ne doit pas dépendre de la largeur, sinon la carte change de taille d'un
        // téléphone à l'autre.
        XCTAssertEqual(StreakWeekTracker.Size.prominent.rowHeight, 38 + 16)
        XCTAssertEqual(StreakWeekTracker.Size.compact.rowHeight, 30 + 16)
    }
}
