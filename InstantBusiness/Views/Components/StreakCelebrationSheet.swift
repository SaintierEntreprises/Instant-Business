import SwiftUI
import UIKit

/// Célébration de série, présentée en bottom sheet.
///
/// Apparaît à la première ouverture de la journée, et systématiquement quand on arrive
/// par le rappel de série : c'est précisément à ce moment-là que la question « est-ce que
/// ma série tient toujours ? » se pose, et l'écran d'accueil n'y répondait que par un
/// petit chiffre dans un coin.
///
/// Deux régimes dans un seul écran plutôt que deux écrans : le jour ordinaire, et le jour
/// où un palier tombe. Ce second cas change l'emblème, le titre et propose le partage —
/// mais garde la même structure, pour qu'on reconnaisse l'écran qu'on voit tous les jours.
struct StreakCelebrationSheet: View {
    let streak: Int
    let bestStreak: Int
    let days: [StreakDay]
    var firstName: String?
    /// Palier franchi aujourd'hui, quand c'est le cas.
    var milestone: StreakBadge?
    /// Jour manqué qu'un joker vient de couvrir, à annoncer explicitement.
    var freezeSavedDay: Date?
    var freezesRemaining: Int = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var haloPulse = false
    @State private var emblemLanded = false
    @State private var bounce = 0
    @State private var shareItem: StreakShareItem?

    private struct StreakShareItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private var completedThisWeek: Int {
        days.filter { $0.isOpened || $0.isFrozen }.count
    }

    private var accentGradient: LinearGradient {
        milestone?.gradient ?? StreakPalette.flameDiagonal
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                emblem
                    .padding(.top, 10)

                if let milestone {
                    Text("PALIER ATTEINT")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(.secondary)
                    Text(milestone.name)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(milestone.gradient)
                        .padding(.top, 2)
                }

                Text("\(streak)")
                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                    .foregroundStyle(accentGradient)
                    .contentTransition(.numericText())
                    .padding(.top, milestone == nil ? 6 : 4)

                Text(streak > 1 ? "jours de suite" : "jour de suite")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(message)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)

                if let freezeSavedDay {
                    freezeNotice(for: freezeSavedDay)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }

                weekCard
                    .padding(.horizontal, 20)
                    .padding(.top, 22)

                if bestStreak > streak, milestone == nil {
                    infoRow(icon: "trophy.fill", color: .yellow, text: "Ton record : \(bestStreak) jours")
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                if freezeSavedDay == nil, freezesRemaining > 0 {
                    infoRow(
                        icon: "snowflake",
                        color: StreakPalette.frostTint,
                        text: "\(freezesRemaining) joker\(freezesRemaining > 1 ? "s" : "") pour rattraper un jour manqué"
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }

                actions
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fontDesign(.rounded)
        .presentationDetents([.fraction(milestone == nil ? 0.9 : 0.94)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Color(.systemBackground))
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
        .task { await playEntrance() }
    }

    // MARK: - Boutons

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            if milestone != nil {
                Button {
                    Haptics.commit()
                    share()
                } label: {
                    Label("Partager ce palier", systemImage: "square.and.arrow.up")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: (milestone?.colors.first ?? StreakPalette.tint).opacity(0.35), radius: 12, y: 6)
                }
                .buttonStyle(.pressable)

                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Text("Continuer")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        // 16 et non 12 : c'est le dernier élément de la feuille, donc
                        // celui qu'on vise le plus mal, et un texte nu n'offre aucune
                        // cible visible. En dessous de 44 pt de haut on le rate.
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            } else {
                Button {
                    Haptics.commit()
                    dismiss()
                } label: {
                    Text(streak > 1 ? "Continuer sur ma lancée" : "C'est parti")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(StreakPalette.flameDiagonal, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: StreakPalette.tint.opacity(0.35), radius: 12, y: 6)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    private func share() {
        guard let image = StreakShareRenderer.uiImage(streak: streak, badge: milestone, days: days) else { return }
        Analytics.track(.streakShared, [
            "streak": .int(streak),
            "milestone": .int(milestone?.days ?? 0)
        ])
        shareItem = StreakShareItem(image: image)
    }

    // MARK: - Emblème

    private var emblem: some View {
        ZStack {
            // Deux halos décalés plutôt qu'une ombre : la flamme paraît alors éclairer la
            // sheet, au lieu d'y être posée.
            ForEach(0..<2, id: \.self) { ring in
                Circle()
                    .fill((milestone?.colors.first ?? StreakPalette.tint).opacity(0.16 - Double(ring) * 0.07))
                    .frame(width: 102 + CGFloat(ring) * 40, height: 102 + CGFloat(ring) * 40)
                    .scaleEffect(haloPulse ? 1.06 : 0.94)
                    .animation(
                        reduceMotion
                        ? nil
                        : .easeInOut(duration: 2.4 + Double(ring) * 0.6).repeatForever(autoreverses: true),
                        value: haloPulse
                    )
            }

            if !reduceMotion {
                embers
            }

            Circle()
                .fill(milestone?.gradient ?? StreakPalette.flame)
                .frame(width: 90, height: 90)
                .shadow(color: (milestone?.colors.first ?? StreakPalette.tint).opacity(0.5), radius: 20, y: 10)

            Image(systemName: milestone?.icon ?? "flame.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: bounce)
        }
        .frame(height: 158)
        .scaleEffect(emblemLanded || reduceMotion ? 1 : 0.55)
        .opacity(emblemLanded || reduceMotion ? 1 : 0)
        .accessibilityHidden(true)
    }

    /// Braises qui montent derrière la flamme. Purement décoratif, coupé dès que
    /// l'animation réduite est demandée.
    private var embers: some View {
        ForEach(0..<8, id: \.self) { index in
            let angle = Double(index) / 8 * 2 * .pi
            Circle()
                .fill((milestone?.colors.first ?? StreakPalette.tint).opacity(0.55))
                .frame(width: index.isMultiple(of: 3) ? 6 : 4)
                .offset(
                    x: cos(angle) * 66,
                    y: sin(angle) * 54 + (haloPulse ? -10 : 6)
                )
                .opacity(haloPulse ? 0.15 : 0.7)
                .animation(
                    .easeInOut(duration: 1.8 + Double(index) * 0.14)
                        .repeatForever(autoreverses: true),
                    value: haloPulse
                )
        }
    }

    // MARK: - Blocs

    private var weekCard: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Cette semaine")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Spacer()
                Text("\(completedThisWeek)/7")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(StreakPalette.tint)
            }

            StreakWeekTracker(days: days, size: .prominent, animatesEntrance: true)

            // Masquée le jour d'un palier : elle repart du palier qu'on vient d'atteindre
            // et affiche donc une barre vide, au moment précis où l'écran est censé
            // célébrer quelque chose.
            if milestone == nil {
                StreakMilestoneBar(streak: streak)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// Annonce explicite du joker consommé.
    ///
    /// Sans elle, la série continuerait après une journée manquée sans que personne
    /// comprenne pourquoi — et le jour où il n'y a plus de joker, la remise à 1
    /// paraîtrait arbitraire.
    private func freezeNotice(for day: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "snowflake")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(StreakPalette.frost, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Un joker a sauvé ta série")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text("\(weekdayName(for: day)) n'a pas compté. Il t'en reste \(freezesRemaining) ce mois-ci.")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(StreakPalette.frostTint.opacity(0.12))
        )
    }

    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func weekdayName(for date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "fr_FR"))).capitalized
    }

    // MARK: - Texte

    private var message: String {
        let name = (firstName?.isEmpty == false) ? firstName! : nil

        if let milestone {
            switch milestone.days {
            case 3: return "Trois jours, c'est le cap où la plupart s'arrêtent. Pas toi."
            case 7: return "Une semaine entière. L'habitude commence à tenir toute seule."
            case 30: return "Un mois complet. C'est devenu une routine, plus un effort."
            case 365: return "Une année entière, sans en manquer un seul. Chapeau."
            default: return "\(milestone.days) jours d'affilée. Ce palier est à toi."
            }
        }

        switch streak {
        case ..<2:
            return name.map { "\($0), le premier jour est posé. Reviens demain et la série démarre vraiment." }
                ?? "Le premier jour est posé. Reviens demain et la série démarre vraiment."
        case 2...6:
            return name.map { "Beau rythme \($0). C'est là que l'habitude se joue." }
                ?? "Beau rythme. C'est là que l'habitude se joue."
        case 7...29:
            return "Une semaine tenue, puis une autre. Peu de gens vont jusque-là."
        default:
            return "\(streak) jours sans en manquer un seul. Ça ne doit plus rien au hasard."
        }
    }

    // MARK: - Entrée

    /// Un retour haptique par jour de la série qui s'allume, puis un dernier, plus ample,
    /// à la fin. La cadence suit exactement celle des ronds : le geste et le son se lisent
    /// comme un seul évènement plutôt que comme deux couches superposées.
    private func playEntrance() async {
        Haptics.prepare()
        haloPulse = true
        withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) {
            emblemLanded = true
        }

        guard !reduceMotion else {
            Haptics.success()
            return
        }

        let lit = days.filter(\.isInCurrentStreak).count
        for _ in 0..<max(lit, 1) {
            try? await Task.sleep(nanoseconds: 60_000_000)
            Haptics.tap()
        }
        try? await Task.sleep(nanoseconds: 140_000_000)
        Haptics.success()
        bounce += 1

        // Un palier mérite d'être senti plus longtemps qu'un jour ordinaire — c'est la
        // seule chose qui distingue les deux au toucher.
        if milestone != nil {
            try? await Task.sleep(nanoseconds: 220_000_000)
            Haptics.commit()
            try? await Task.sleep(nanoseconds: 120_000_000)
            Haptics.success()
        }
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            StreakCelebrationSheet(
                streak: 7,
                bestStreak: 12,
                days: StreakWeek.days(
                    streak: 7,
                    openDays: {
                        let calendar = StreakWeek.calendar
                        let today = calendar.startOfDay(for: Date())
                        return Set((0..<7).compactMap { offset in
                            calendar.date(byAdding: .day, value: -offset, to: today)
                                .map(SharedDefaults.dayKey(for:))
                        })
                    }()
                ),
                firstName: "Melvyn",
                milestone: StreakBadge.badge(for: 7),
                freezesRemaining: 1
            )
        }
}
