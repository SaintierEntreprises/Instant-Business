import SwiftUI

/// Dégradé de la flamme, partagé par le tracker, la célébration et les réglages.
///
/// Défini une fois : les trois endroits doivent porter exactement la même couleur pour
/// qu'on les lise comme un seul objet déplacé d'un écran à l'autre.
enum StreakPalette {
    static let flame = LinearGradient(
        colors: [Color(red: 1.00, green: 0.68, blue: 0.20), Color(red: 0.95, green: 0.31, blue: 0.16)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let flameDiagonal = LinearGradient(
        colors: [Color(red: 1.00, green: 0.72, blue: 0.24), Color(red: 0.93, green: 0.26, blue: 0.20)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let tint = Color(red: 0.97, green: 0.44, blue: 0.13)

    /// Jour gelé : volontairement froid, pour qu'un joker ne se confonde jamais avec une
    /// journée réellement faite, même du coin de l'œil.
    static let frost = LinearGradient(
        colors: [Color(red: 0.55, green: 0.78, blue: 0.98), Color(red: 0.33, green: 0.56, blue: 0.92)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let frostTint = Color(red: 0.40, green: 0.64, blue: 0.95)
}

/// Semaine lundi → dimanche, un rond par jour, la série en cours soulignée par un bandeau
/// continu qui court sous les jours consécutifs.
///
/// Sept ronds isolés se lisent comme sept cases à cocher indépendantes, alors qu'une série
/// est précisément le contraire : une continuité qu'une seule journée manquée interrompt.
/// Le bandeau porte cette information. Il a remplacé de fins traits entre les ronds, qui
/// ne tenaient pas la largeur — sept ronds sur la largeur d'un iPhone ne laissent que
/// quatre points entre chacun, illisibles.
struct StreakWeekTracker: View {
    enum Size {
        case compact
        case prominent

        var circle: CGFloat { self == .prominent ? 38 : 30 }
        var glyph: Font {
            .system(size: self == .prominent ? 17 : 14, weight: .bold, design: .rounded)
        }
        var label: Font {
            .system(size: self == .prominent ? 13 : 11, weight: .semibold, design: .rounded)
        }
        var spacing: CGFloat { self == .prominent ? 10 : 8 }
    }

    let days: [StreakDay]
    var size: Size = .prominent
    /// Les ronds se posent l'un après l'autre. Réservé à la célébration : dans les
    /// réglages, une grille qui s'anime à chaque affichage de l'écran deviendrait vite un
    /// tic plutôt qu'un évènement.
    var animatesEntrance = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var isRevealed: Bool { revealed || !animatesEntrance || reduceMotion }

    var body: some View {
        VStack(spacing: size.spacing) {
            HStack(spacing: 0) {
                ForEach(days) { day in
                    Text(day.initial)
                        .font(size.label)
                        .foregroundStyle(day.isToday ? AnyShapeStyle(StreakPalette.tint) : AnyShapeStyle(Color.secondary))
                        .frame(maxWidth: .infinity)
                }
            }

            ZStack(alignment: .leading) {
                GeometryReader { proxy in
                    streakBand(width: proxy.size.width)
                }

                HStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        marker(for: day)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(isRevealed ? 1 : 0.4)
                            .opacity(isRevealed ? 1 : 0)
                            .animation(
                                .spring(response: 0.42, dampingFraction: 0.62)
                                    .delay(reduceMotion ? 0 : Double(index) * 0.06),
                                value: isRevealed
                            )
                    }
                }
            }
        }
        .onAppear { revealed = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Semaine en cours")
    }

    // MARK: - Bandeau de série

    /// Bandeau posé sous les jours consécutifs de la série en cours.
    ///
    /// Un seul bandeau suffit : une série est par définition contiguë, ses jours ne
    /// peuvent pas être séparés dans la semaine.
    @ViewBuilder
    private func streakBand(width: CGFloat) -> some View {
        if let first = days.firstIndex(where: \.isInCurrentStreak),
           let last = days.lastIndex(where: \.isInCurrentStreak) {
            let column = width / CGFloat(max(days.count, 1))
            let height = size.circle + 14
            let bandWidth = CGFloat(last - first) * column + height
            let leading = (CGFloat(first) + 0.5) * column - height / 2

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(StreakPalette.tint.opacity(0.16))
                    .frame(width: bandWidth, height: height)
                    .offset(x: leading)
                    .scaleEffect(x: isRevealed ? 1 : 0.2, anchor: .leading)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8), value: isRevealed)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    // MARK: - Ronds

    @ViewBuilder
    private func marker(for day: StreakDay) -> some View {
        ZStack {
            // Anneau d'aujourd'hui, posé à l'extérieur du rond : c'est le seul repère qui
            // dit où on se trouve dans la semaine sans ajouter de texte.
            if day.isToday {
                Circle()
                    .strokeBorder(StreakPalette.tint.opacity(0.35), lineWidth: 2)
                    .frame(width: size.circle + 9, height: size.circle + 9)
            }

            Group {
                if day.isFrozen {
                    // Gelé : dans la série, donc dans le bandeau, mais jamais habillé en
                    // journée faite.
                    Circle()
                        .fill(StreakPalette.frost)
                        .shadow(color: StreakPalette.frostTint.opacity(0.35), radius: 5, y: 2)
                    Image(systemName: "snowflake")
                        .font(size.glyph)
                        .foregroundStyle(.white)
                } else if day.isInCurrentStreak {
                    Circle()
                        .fill(StreakPalette.flame)
                        .shadow(color: StreakPalette.tint.opacity(0.35), radius: 5, y: 2)
                    Image(systemName: day.isToday ? "flame.fill" : "checkmark")
                        .font(size.glyph)
                        .foregroundStyle(.white)
                } else if day.isOpened {
                    // Fait, mais avant une coupure : marqué sans être célébré. L'effacer
                    // serait faux, lui donner la flamme laisserait croire la série intacte.
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                    Image(systemName: "checkmark")
                        .font(size.glyph)
                        .foregroundStyle(.secondary)
                } else if day.isFuture {
                    Circle()
                        .strokeBorder(
                            Color.primary.opacity(0.12),
                            style: StrokeStyle(lineWidth: 2, dash: [2.5, 4])
                        )
                } else {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 2)
                }
            }
            .frame(width: size.circle, height: size.circle)
        }
        .frame(width: size.circle + 16, height: size.circle + 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.fullName)
        .accessibilityValue(accessibilityValue(for: day))
    }

    private func accessibilityValue(for day: StreakDay) -> String {
        if day.isFrozen { return "sauvé par un joker" }
        if day.isInCurrentStreak { return day.isToday ? "fait aujourd'hui" : "fait" }
        if day.isOpened { return "fait, hors série" }
        if day.isFuture { return "à venir" }
        return day.isToday ? "pas encore fait" : "manqué"
    }
}

/// Barre d'avancement vers le palier suivant.
///
/// Le compteur de jours ne dit jamais où on va ; la barre transforme « 5 jours » en
/// « plus que 2 avant 7 ». Elle repart du palier précédent plutôt que de zéro, sinon les
/// derniers jours avant un palier lointain paraîtraient n'avoir rien fait avancer.
struct StreakMilestoneBar: View {
    let streak: Int
    var showsCaption = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false

    var body: some View {
        if let progress = StreakMilestone.progress(streak: streak) {
            VStack(alignment: .leading, spacing: 7) {
                if showsCaption {
                    // Une seule information sur la ligne : la version précédente affichait
                    // aussi « 5/7 » à droite, juste sous le « 6/7 » de la semaine, et les
                    // deux fractions se lisaient comme la même mesure.
                    Text(progress.remaining <= 0
                         ? "Palier atteint"
                         : "Plus que \(progress.remaining) jour\(progress.remaining > 1 ? "s" : "") avant le palier de \(progress.next)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.07))
                        Capsule()
                            .fill(StreakPalette.flameDiagonal)
                            .frame(width: proxy.size.width * (filled || reduceMotion ? progress.fraction : 0))
                    }
                }
                .frame(height: 8)
            }
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.9).delay(0.15)) {
                    filled = true
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Progression vers \(progress.next) jours")
            .accessibilityValue("\(streak) jours sur \(progress.next)")
        }
    }
}

#Preview("Tracker") {
    VStack(spacing: 40) {
        StreakWeekTracker(
            days: StreakWeek.days(streak: 3, openDays: previewDays),
            size: .prominent
        )
        StreakWeekTracker(
            days: StreakWeek.days(streak: 3, openDays: previewDays),
            size: .compact
        )
        StreakMilestoneBar(streak: 5)
    }
    .padding(24)
    .fontDesign(.rounded)
}

private var previewDays: Set<String> {
    let calendar = StreakWeek.calendar
    let today = calendar.startOfDay(for: Date())
    return Set((0..<3).compactMap { offset in
        calendar.date(byAdding: .day, value: -offset, to: today).map(SharedDefaults.dayKey(for:))
    })
}
