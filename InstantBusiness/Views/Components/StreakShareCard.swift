import SwiftUI
import UIKit

/// Carte partageable produite au franchissement d'un palier.
///
/// Le palier est le seul moment de l'app qu'on a envie de montrer : une citation se
/// partage pour ce qu'elle dit, un palier se partage pour ce qu'on a fait. C'est aussi le
/// seul canal d'acquisition qui ne coûte rien — d'où la signature, discrète mais présente,
/// reprise du même traitement que les citations partagées.
struct StreakShareCard: View {
    let streak: Int
    let badge: StreakBadge?
    let days: [StreakDay]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.09, blue: 0.16), Color(red: 0.05, green: 0.04, blue: 0.09)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Lueur chaude derrière l'emblème : sans elle le fond sombre écrase le
            // dégradé de la flamme et la carte tombe à plat.
            Circle()
                .fill((badge?.colors.first ?? StreakPalette.tint).opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(y: -110)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(badge?.gradient ?? StreakPalette.flame)
                        .frame(width: 116, height: 116)
                        .shadow(color: (badge?.colors.first ?? StreakPalette.tint).opacity(0.55), radius: 26, y: 10)
                    Image(systemName: badge?.icon ?? "flame.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 54)

                Text("\(streak)")
                    .font(.system(size: 86, weight: .heavy, design: .rounded))
                    .foregroundStyle(badge?.gradient ?? StreakPalette.flameDiagonal)
                    .padding(.top, 18)

                Text(streak > 1 ? "jours de suite" : "jour de suite")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                if let badge {
                    Text(badge.name.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.14), in: Capsule())
                        .padding(.top, 20)
                }

                Spacer(minLength: 0)

                weekRow
                    .padding(.horizontal, 44)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 13))
                    Text("Instant Business")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .tracking(0.2)
                }
                .foregroundStyle(.white.opacity(0.45))
                .padding(.bottom, 34)
            }
        }
        .frame(width: 400, height: 533)
    }

    /// Version figée du tracker : le composant animé de l'app dépend d'un `GeometryReader`
    /// et d'un état d'apparition, deux choses qu'`ImageRenderer` ne fait pas tourner.
    private var weekRow: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 7) {
                    Text(day.initial)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    ZStack {
                        if day.isFrozen {
                            Circle().fill(StreakPalette.frost)
                            Image(systemName: "snowflake")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else if day.isInCurrentStreak {
                            Circle().fill(StreakPalette.flame)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Circle().strokeBorder(.white.opacity(0.16), lineWidth: 2)
                        }
                    }
                    .frame(width: 28, height: 28)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

@MainActor
enum StreakShareRenderer {
    static func uiImage(streak: Int, badge: StreakBadge?, days: [StreakDay]) -> UIImage? {
        let renderer = ImageRenderer(content: StreakShareCard(streak: streak, badge: badge, days: days))
        // Même échelle que les citations partagées : 1200×1599, net en story sans peser.
        renderer.scale = 3
        return renderer.uiImage
    }
}
