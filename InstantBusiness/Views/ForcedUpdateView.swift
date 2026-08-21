import SwiftUI

/// Écran bloquant affiché quand la version installée est antérieure au minimum exigé.
/// Aucune sortie volontaire : c'est tout l'objet du blocage. Le seul chemin est la fiche
/// App Store.
struct ForcedUpdateView: View {
    var requiredVersion: String?
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(color: .orange.opacity(0.35), radius: 24, y: 12)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
            }
            .scaleEffect(settled ? 1 : 0.85)
            .opacity(settled ? 1 : 0)

            Text("Mise à jour requise")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .padding(.top, 28)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 36)
                .padding(.top, 10)

            Spacer()

            Button {
                Haptics.commit()
                if let url = AppUpdateGate.appStoreURL { openURL(url) }
            } label: {
                Text("Mettre à jour")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .onAppear {
            guard !reduceMotion else {
                settled = true
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { settled = true }
        }
    }

    private var message: String {
        if let requiredVersion {
            return "Cette version d'Instant Business n'est plus prise en charge. Installe la version \(requiredVersion) ou plus récente pour continuer."
        }
        return "Cette version d'Instant Business n'est plus prise en charge. Installe la dernière version pour continuer."
    }
}

#Preview {
    ForcedUpdateView(requiredVersion: "1.2")
}
