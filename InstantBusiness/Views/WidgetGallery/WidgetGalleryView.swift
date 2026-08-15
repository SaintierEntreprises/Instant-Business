import SwiftUI

struct WidgetGalleryView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Thèmes de widget",
                systemImage: "square.grid.2x2",
                description: Text("La galerie de thèmes arrive bientôt.")
            )
            .navigationTitle("Widget")
        }
    }
}

#Preview {
    WidgetGalleryView()
}
