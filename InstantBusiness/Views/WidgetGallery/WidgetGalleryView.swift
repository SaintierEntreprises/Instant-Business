import SwiftUI

struct WidgetGalleryView: View {
    @EnvironmentObject private var store: StoreManager
    @State private var showPaywall = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Ajoute le widget Instant Business à ton écran d'accueil ou de verrouillage, puis choisis un thème en maintenant le widget appuyé.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(WidgetTheme.allCases, id: \.self) { theme in
                            themeCard(theme)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Widget")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func themeCard(_ theme: WidgetTheme) -> some View {
        let locked = !theme.isFree && !store.isPremium
        return Button {
            if locked { showPaywall = true }
        } label: {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: theme.previewGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.35), in: Circle())
                        .padding(10)
                }

                Text(theme.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme == .minimal ? Color.primary : Color.white)
                    .padding(10)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WidgetGalleryView()
        .environmentObject(StoreManager())
}
