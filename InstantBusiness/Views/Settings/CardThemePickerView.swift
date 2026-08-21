import SwiftUI

struct CardThemePickerView: View {
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    private var sampleQuote: Quote {
        ContentStore.quoteOfTheDay(category: .mindset, maxLength: 90)
            ?? Quote(id: "s", text: "Fais de chaque jour ton chef-d'œuvre.", author: "John Wooden", category: .mindset)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(CardTheme.allCases) { theme in
                        themeCell(theme)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Thème des cartes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func themeCell(_ theme: CardTheme) -> some View {
        let locked = !theme.isFree && !store.isPremium
        let isSelected = appearance.cardTheme == theme

        return Button {
            if locked {
                showPaywall = true
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    Analytics.track(.cardThemeChanged, ["theme": .string(theme.rawValue)])
                    appearance.cardTheme = theme
                }
            }
        } label: {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    preview(theme)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(.black.opacity(0.45), in: Circle())
                            .padding(8)
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Color.accentColor, in: Circle())
                            .padding(8)
                    }
                }

                HStack(spacing: 6) {
                    Text(theme.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if theme.isFree {
                        Text("GRATUIT")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15), in: Capsule())
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
    }

    private func preview(_ theme: CardTheme) -> some View {
        let quote = sampleQuote
        return ZStack {
            theme.background(for: quote.category)

            VStack(alignment: .leading, spacing: 6) {
                Text(quote.category.displayName.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(theme.pillForeground(for: quote.category))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(theme.pillBackground(for: quote.category), in: Capsule())
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(quote.text)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textColor)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                Text("— \(quote.author)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.secondaryTextColor)
                    .lineLimit(1)
            }
            .padding(14)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(appearance.cardTheme == theme ? Color.accentColor : theme.borderColor,
                        lineWidth: appearance.cardTheme == theme ? 2.5 : 1)
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview {
    CardThemePickerView()
        .environmentObject(AppearanceStore())
        .environmentObject(StoreManager())
}
