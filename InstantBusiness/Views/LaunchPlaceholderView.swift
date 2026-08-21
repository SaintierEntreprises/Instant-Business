import SwiftUI

/// Shown while the stored session is being restored, so the app never flashes the
/// login screen to someone who is in fact already signed in.
struct LaunchPlaceholderView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 108, height: 108)
                    .shadow(color: .orange.opacity(0.35), radius: 24, y: 12)
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            // Le logo se pose au lieu d'apparaître d'un coup : la restauration de session
            // dure de toute façon quelques centaines de millisecondes, autant qu'elles
            // ressemblent à une mise en route plutôt qu'à un temps mort.
            .scaleEffect(settled ? 1 : 0.88)
            .opacity(settled ? 1 : 0)
        }
        .onAppear {
            guard !reduceMotion else {
                settled = true
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { settled = true }
        }
    }
}

#Preview {
    LaunchPlaceholderView()
}
