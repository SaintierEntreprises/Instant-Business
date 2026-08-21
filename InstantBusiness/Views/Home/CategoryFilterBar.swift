import SwiftUI

struct CategoryFilterBar: View {
    @EnvironmentObject private var store: StoreManager
    @Binding var selectedCategory: QuoteCategory?
    var onLockedCategoryTap: (QuoteCategory) -> Void = { _ in }
    @Namespace private var namespace

    private var items: [QuoteCategory?] { [nil] + QuoteCategory.allCases }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.self) { item in
                    chip(for: item)
                }
            }
            // 24 comme le reste du fil : à 16, la puce « Tout » ne s'alignait pas sur le
            // titre « DÉCOUVRIR » juste au-dessus.
            .padding(.horizontal, 24)
        }
        // Sans ce dégradé, la puce de droite est tranchée net au bord de l'écran et se lit
        // comme un défaut de mise en page plutôt que comme « ça continue ».
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    @ViewBuilder
    private func chip(for item: QuoteCategory?) -> some View {
        let isSelected = selectedCategory == item
        let locked = item.map(isLocked) ?? false

        Button {
            if locked, let item {
                Haptics.tap()
                onLockedCategoryTap(item)
            } else {
                Haptics.select()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    selectedCategory = item
                }
            }
        } label: {
            HStack(spacing: 4) {
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
                Text(item?.displayName ?? "Tout")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.accentColor)
                        .matchedGeometryEffect(id: "chip-selection", in: namespace)
                } else {
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                }
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.92))
    }

    private func isLocked(_ category: QuoteCategory) -> Bool {
        category != .mindset && !store.isPremium
    }
}
