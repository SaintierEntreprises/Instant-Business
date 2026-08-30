import SwiftUI

/// Les citations du jour déjà vécues, de la plus récente à la plus ancienne.
///
/// La série donnait un nombre à regarder ; le journal donne quelque chose à relire. C'est
/// aussi ce qui rend concret ce qu'on perd en cassant une série : non plus un compteur qui
/// retombe, mais une collection qui s'arrête.
struct JournalView: View {
    @State private var detailQuote: Quote?

    private var entries: [JournalEntry] {
        Journal.entries(
            openDays: SharedDefaults.openDays,
            frozenDays: SharedDefaults.frozenDays,
            remembered: SharedDefaults.dailyQuoteIDs
        )
    }

    var body: some View {
        ScrollView {
            if entries.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        Button {
                            Haptics.tap()
                            detailQuote = entry.quote
                        } label: {
                            row(entry)
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.98))
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Mon journal")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(.rounded)
        .sheet(item: $detailQuote) { QuoteDetailView(quote: $0) }
        .onAppear { Haptics.prepare() }
    }

    private func row(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text(Self.dayLabel(for: entry.date))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(StreakPalette.tint)
                    .textCase(.uppercase)

                if entry.isFrozen {
                    // Le flocon dit pourquoi la journée figure ici sans avoir été ouverte.
                    Image(systemName: "snowflake")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.cyan)
                }

                Spacer()

                Image(systemName: entry.quote.category.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(entry.quote.text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            Text("— \(entry.quote.author)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(StreakPalette.tint.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(StreakPalette.tint)
            }

            VStack(spacing: 6) {
                Text("Ton journal est encore vide")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text("Chaque jour où tu ouvres l'app, la citation du jour vient s'ajouter ici.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .padding(.top, 60)
    }

    /// « Aujourd'hui » et « hier » plutôt qu'une date : ce sont les deux entrées qu'on
    /// relit le plus, et les nommer évite de faire calculer le lecteur.
    static func dayLabel(
        for date: Date,
        today: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: today) { return "Aujourd'hui" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Hier"
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        // L'année n'apparaît que si elle diffère : la répéter sur chaque ligne d'un journal
        // consulté au fil des semaines n'apprendrait rien.
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: today)
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "EEEEdMMMM" : "dMMMMyyyy")
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack { JournalView() }
}
