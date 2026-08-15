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
    static func uiImage(for quote: Quote) -> UIImage? {
        let view = QuoteCardView(quote: quote, showControls: false)
            .frame(width: 400, height: 533)

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

struct ShareItem: Identifiable {
    let quote: Quote
    var id: String { quote.id }
}
