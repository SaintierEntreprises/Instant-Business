import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@MainActor
enum ShareCardRenderer {
    static func uiImage(for quote: Quote, theme: CardTheme = SharedDefaults.cardTheme) -> UIImage? {
        let renderer = ImageRenderer(content: QuoteShareCard(quote: quote, theme: theme))
        // Échelle fixe plutôt que celle de l'écran : sur un appareil en @2x, l'image
        // sortait molle une fois affichée en plein écran. 540 × 675 à l'échelle 2 donne
        // 1080 × 1350, la définition qu'Instagram attend sans rééchantillonner.
        renderer.scale = 2
        // Sans fond opaque, les pixels transparents de l'image sont composés par la
        // destination : c'est ce qui donnait des angles rognés sur Instagram.
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

struct ShareItem: Identifiable {
    let quote: Quote
    var id: String { quote.id }
}
