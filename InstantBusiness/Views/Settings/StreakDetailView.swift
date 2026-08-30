import SwiftUI

/// Archive de la série : le mois en cours, les paliers gagnés, les jokers restants.
///
/// Séparée de la célébration, et pas par commodité de découpage : la sheet est un moment,
/// qui doit tenir en un coup d'œil et se refermer ; cet écran est un dossier, qu'on ouvre
/// quand on veut regarder ce qu'on a fait. Mettre les deux au même endroit aurait allongé
/// la sheet quotidienne jusqu'à ce qu'on cesse de la lire.
struct StreakDetailView: View {
    @AppStorage(SharedDefaults.streakCountKey, store: SharedDefaults.suite)
    private var streak = 0
    @AppStorage(SharedDefaults.bestStreakKey, store: SharedDefaults.suite)
    private var bestStreak = 0

    @State private var monthAnchor = Date()

    private var openDays: Set<String> { SharedDefaults.openDays }
    private var frozenDays: Set<String> { SharedDefaults.frozenDays }

    private var calendar: Calendar { StreakWeek.calendar }

    private var monthCells: [StreakDay?] {
        StreakWeek.month(
            containing: monthAnchor,
            streak: streak,
            openDays: openDays,
            frozenDays: frozenDays
        )
    }

    /// Total de jours réellement ouverts. Les jours gelés en sont exclus : ce compteur
    /// mesure la présence, pas la série.
    private var totalDays: Int { openDays.count }

    private var canGoBack: Bool {
        guard let earliest = StreakWeek.earliestRecordedDay(openDays: openDays, frozenDays: frozenDays),
              let start = calendar.dateInterval(of: .month, for: monthAnchor)?.start
        else { return false }
        return earliest < start
    }

    private var canGoForward: Bool {
        guard let end = calendar.dateInterval(of: .month, for: monthAnchor)?.end else { return false }
        return end <= Date()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                summary
                journalRow
                monthCard
                badgesCard
                freezeCard
            }
            .padding(20)
            // La barre d'onglets flotte au-dessus du contenu : sans cette marge, la
            // dernière carte s'arrête pile dessous et paraît coupée.
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Ma progression")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(.rounded)
        .onAppear { Haptics.prepare() }
    }

    // MARK: - Résumé

    private var summary: some View {
        HStack(spacing: 12) {
            statTile(value: "\(streak)", label: streak > 1 ? "jours de suite" : "jour de suite", tint: StreakPalette.tint)
            statTile(value: "\(max(bestStreak, streak))", label: "record", tint: .yellow)
            statTile(value: "\(totalDays)", label: totalDays > 1 ? "jours au total" : "jour au total", tint: .indigo)
        }
    }

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Journal

    /// Placé juste sous le résumé : c'est la contrepartie des chiffres qu'on vient de
    /// lire, et la seule partie de cet écran qu'on peut réellement parcourir.
    private var journalRow: some View {
        NavigationLink {
            JournalView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(StreakPalette.tint)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mon journal")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(journalCaption)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
    }

    private var journalCaption: String {
        totalDays > 1
            ? "Les \(totalDays) citations que tu as déjà lues"
            : "Retrouve tes citations du jour, jour après jour"
    }

    // MARK: - Calendrier

    private var monthCard: some View {
        VStack(spacing: 16) {
            HStack {
                monthButton(systemName: "chevron.left", enabled: canGoBack, offset: -1)
                Spacer()
                Text(monthAnchor.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Spacer()
                monthButton(systemName: "chevron.right", enabled: canGoForward, offset: 1)
            }

            HStack(spacing: 0) {
                ForEach(Array(["L", "M", "M", "J", "V", "S", "D"].enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let cells = monthCells
            VStack(spacing: 6) {
                ForEach(0..<(cells.count / 7), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { column in
                            monthCell(cells[row * 7 + column])
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func monthButton(systemName: String, enabled: Bool, offset: Int) -> some View {
        Button {
            guard let next = calendar.date(byAdding: .month, value: offset, to: monthAnchor) else { return }
            Haptics.select()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                monthAnchor = next
            }
        } label: {
            Image(systemName: systemName)
                .font(.footnote.weight(.bold))
                .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.35))
                .frame(width: 30, height: 30)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.9))
        .disabled(!enabled)
    }

    @ViewBuilder
    private func monthCell(_ day: StreakDay?) -> some View {
        if let day {
            ZStack {
                if day.isFrozen {
                    Circle().fill(StreakPalette.frost)
                } else if day.isOpened {
                    Circle().fill(day.isInCurrentStreak
                                  ? AnyShapeStyle(StreakPalette.flame)
                                  : AnyShapeStyle(StreakPalette.tint.opacity(0.22)))
                } else if day.isToday {
                    Circle().strokeBorder(StreakPalette.tint.opacity(0.45), lineWidth: 2)
                }

                Text(day.initial)
                    .font(.system(size: 12, weight: day.isToday ? .heavy : .semibold, design: .rounded))
                    .foregroundStyle(cellForeground(day))
            }
            .frame(width: 32, height: 32)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(day.fullName)
            .accessibilityValue(day.isFrozen ? "joker" : (day.isOpened ? "fait" : "non ouvert"))
        } else {
            Color.clear.frame(width: 32, height: 32)
        }
    }

    private func cellForeground(_ day: StreakDay) -> Color {
        if day.isFrozen { return .white }
        if day.isOpened { return day.isInCurrentStreak ? .white : StreakPalette.tint }
        if day.isFuture { return .secondary.opacity(0.35) }
        return .secondary
    }

    // MARK: - Insignes

    private var badgesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Paliers")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Spacer()
                Text("\(earnedCount)/\(StreakBadge.all.count)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(StreakPalette.tint)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 18) {
                ForEach(StreakBadge.all) { badge in
                    badgeCell(badge)
                }
            }

            Text(nextBadgeCaption)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var earnedCount: Int {
        StreakBadge.all.filter { $0.isEarned(bestStreak: max(bestStreak, streak)) }.count
    }

    private var nextBadgeCaption: String {
        let reference = max(bestStreak, streak)
        guard let next = StreakBadge.all.first(where: { !$0.isEarned(bestStreak: reference) }) else {
            return "Tous les paliers sont gagnés. Il n'en reste plus qu'à tenir."
        }
        let remaining = next.days - streak
        if remaining <= 0 {
            return "« \(next.name) » se débloque en tenant \(next.days) jours d'affilée."
        }
        return "Plus que \(remaining) jour\(remaining > 1 ? "s" : "") avant « \(next.name) »."
    }

    private func badgeCell(_ badge: StreakBadge) -> some View {
        let earned = badge.isEarned(bestStreak: max(bestStreak, streak))
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(earned ? AnyShapeStyle(badge.gradient) : AnyShapeStyle(Color.primary.opacity(0.06)))
                    .frame(width: 52, height: 52)
                    .shadow(color: earned ? badge.colors[0].opacity(0.35) : .clear, radius: 7, y: 3)
                Image(systemName: earned ? badge.icon : "lock.fill")
                    .font(.system(size: earned ? 20 : 15, weight: .semibold))
                    .foregroundStyle(earned ? Color.white : Color.secondary.opacity(0.5))
            }
            Text("\(badge.days) j")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(earned ? .primary : .secondary)
            Text(badge.name)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 22, alignment: .top)
        }
        .opacity(earned ? 1 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.name), \(badge.days) jours")
        .accessibilityValue(earned ? "gagné" : "à débloquer")
    }

    // MARK: - Jokers

    private var freezeCard: some View {
        let remaining = SharedDefaults.freezesRemaining
        return HStack(spacing: 14) {
            Image(systemName: "snowflake")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(StreakPalette.frost, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(remaining > 0
                     ? "\(remaining) joker\(remaining > 1 ? "s" : "") ce mois-ci"
                     : "Plus de joker ce mois-ci")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text("Un joker couvre une journée manquée sans casser ta série. Le quota se renouvelle chaque mois.")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    NavigationStack {
        StreakDetailView()
    }
}
