import SwiftUI

/// Shown while the stored session is being restored, so the app never flashes the
/// login screen to someone who is in fact already signed in.
struct LaunchPlaceholderView: View {
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
        }
    }
}

#Preview {
    LaunchPlaceholderView()
}
