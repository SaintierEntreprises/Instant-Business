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
        let view = QuoteCardView(
            quote: quote,
            showControls: false,
            showSignature: true,
            theme: theme
        )
        .frame(width: 400, height: 533)

        let renderer = ImageRenderer(content: view)
        // Échelle fixe plutôt que celle de l'écran : sur un appareil en @2x, l'image
        // partagée sortait en 800×1066, visiblement molle une fois affichée en story.
        // 1200×1599 est net partout et reste léger.
        renderer.scale = 3
        return renderer.uiImage
    }
}

struct ShareItem: Identifiable {
    let quote: Quote
    var id: String { quote.id }
}
