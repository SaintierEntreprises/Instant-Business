import SwiftUI
import UIKit

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var notificationManager = NotificationManager()
    @State private var page = 0
    @State private var showLogin = false

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
        Group {
            if showLogin {
                LoginView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                onboardingPages
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: showLogin)
        .onChange(of: authManager.session != nil) { _, isSignedIn in
            guard isSignedIn else { return }
            Task {
                await notificationManager.enable(hour: 8, minute: 0)
                complete()
            }
        }
    }

    private var onboardingPages: some View {
        VStack(spacing: 20) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: page)

            pageDots

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if page < pages.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { page += 1 }
                } else {
                    showLogin = true
                }
            } label: {
                Text(page < pages.count - 1 ? "Continuer" : "Se connecter")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 24)
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(width: index == page ? 20 : 7, height: 7)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
            }
        }
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

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [page.tint, page.tint.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .shadow(color: page.tint.opacity(0.4), radius: 24, y: 12)

                Image(systemName: page.symbol)
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
            }

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
        .environmentObject(AuthManager())
}
