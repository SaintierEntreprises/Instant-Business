import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var notificationManager = NotificationManager()
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "flame.fill",
            tint: .orange,
            title: "Instant Business",
            message: "Ta dose quotidienne de mindset et de conseils business, signée par les plus grands entrepreneurs."
        ),
        OnboardingPage(
            symbol: "square.grid.2x2.fill",
            tint: .indigo,
            title: "Ajoute le widget",
            message: "Place le widget Instant Business sur ton écran d'accueil ou de verrouillage pour avoir une citation toujours sous les yeux."
        ),
        OnboardingPage(
            symbol: "bell.badge.fill",
            tint: .pink,
            title: "Une citation par jour",
            message: "Active les notifications pour recevoir ta citation du jour et ne jamais manquer ta dose de motivation."
        )
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    Task {
                        await notificationManager.enable(hour: 8, minute: 0)
                        complete()
                    }
                }
            } label: {
                Text(page < pages.count - 1 ? "Continuer" : "Commencer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 24)

            if page == pages.count - 1 {
                Button("Plus tard") { complete() }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 24)
    }

    private func complete() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

struct OnboardingPage {
    let symbol: String
    let tint: Color
    let title: String
    let message: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: page.symbol)
                .font(.system(size: 64))
                .foregroundStyle(page.tint)
                .frame(width: 140, height: 140)
                .background(page.tint.opacity(0.12))
                .clipShape(Circle())

            Text(page.title)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            Text(page.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
