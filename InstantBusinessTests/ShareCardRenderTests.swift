import XCTest
import SwiftUI
@testable import InstantBusiness

/// Vérifie l'image réellement produite pour le partage.
///
/// Ces contrôles portent sur les pixels sortis, pas sur la vue : c'est la seule façon
/// d'attraper un angle transparent ou une définition qui a glissé, deux défauts invisibles
/// tant qu'on ne regarde pas l'image dans l'app de destination.
@MainActor
final class ShareCardRenderTests: XCTestCase {
    private var sample: Quote {
        ContentStore.allQuotes.first { $0.text.count > 100 } ?? ContentStore.allQuotes[0]
    }

    func testLImageSortEnMilleQuatreVingtParMilleTroisCentCinquante() throws {
        let image = try XCTUnwrap(ShareCardRenderer.uiImage(for: sample))
        XCTAssertEqual(image.size.width * image.scale, 1080, accuracy: 1)
        XCTAssertEqual(image.size.height * image.scale, 1350, accuracy: 1)
    }

    /// Le défaut d'origine : des angles transparents qu'Instagram composait sur son propre
    /// fond, ce qui donnait des coins rognés.
    func testLesQuatreAnglesSontOpaques() throws {
        for theme in CardTheme.allCases {
            let image = try XCTUnwrap(ShareCardRenderer.uiImage(for: sample, theme: theme))
            let cg = try XCTUnwrap(image.cgImage)
            let width = cg.width
            let height = cg.height

            for (x, y) in [(2, 2), (width - 3, 2), (2, height - 3), (width - 3, height - 3)] {
                let alpha = try alphaAt(cg, x: x, y: y)
                XCTAssertEqual(
                    alpha, 255,
                    "angle transparent en (\(x), \(y)) pour le thème \(theme.rawValue)"
                )
            }
        }
    }

    /// Chaque thème doit produire une image, y compris pour la citation la plus longue du
    /// catalogue : c'est celle qui déborderait.
    func testChaqueThemeRendLaCitationLaPlusLongue() throws {
        let longest = try XCTUnwrap(ContentStore.allQuotes.max { $0.text.count < $1.text.count })
        for theme in CardTheme.allCases {
            XCTAssertNotNil(
                ShareCardRenderer.uiImage(for: longest, theme: theme),
                "rendu vide pour le thème \(theme.rawValue)"
            )
        }
    }

    private func alphaAt(_ image: CGImage, x: Int, y: Int) throws -> UInt8 {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = try XCTUnwrap(CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return pixel[3]
    }
}
