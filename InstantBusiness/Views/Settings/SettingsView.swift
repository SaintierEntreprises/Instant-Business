import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Réglages",
                systemImage: "gearshape",
                description: Text("Notifications, streak et abonnement arrivent bientôt.")
            )
            .navigationTitle("Réglages")
        }
    }
}

#Preview {
    SettingsView()
}
