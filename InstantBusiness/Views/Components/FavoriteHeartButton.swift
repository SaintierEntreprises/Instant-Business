import SwiftUI

/// Le geste le plus répété de l'app mérite mieux qu'un simple changement d'icône : un
/// halo part du cœur au moment où la citation est ajoutée. Rien à l'inverse quand on la
/// retire — célébrer un retrait serait un contresens.
///
/// Partagé par la carte du fil et la citation du jour pour que les deux se comportent
/// exactement pareil.
struct FavoriteHeartButton: View {
    let isFavorite: Bool
    var iconFont: Font = .title2
    var hitSize: CGFloat = 44
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var haloScale: CGFloat = 0.5
    @State private var haloOpacity: Double = 0

    var body: some View {
        Button {
            if !isFavorite {
                Haptics.commit()
                burst()
            } else {
                Haptics.tap()
            }
            action()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.pink, lineWidth: 2.5)
                    .scaleEffect(haloScale)
                    .opacity(haloOpacity)
                    .allowsHitTesting(false)

                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(iconFont)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.88))
        .accessibilityLabel(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
    }

    /// Les deux premières affectations sont hors animation : elles fixent le point de
    /// départ, et le `withAnimation` qui suit part donc de cette valeur visible plutôt
    /// que de celle laissée par le halo précédent.
    private func burst() {
        guard !reduceMotion else { return }
        haloScale = 0.5
        haloOpacity = 0.7
        withAnimation(.easeOut(duration: 0.5)) {
            haloScale = 1.9
            haloOpacity = 0
        }
    }
}
