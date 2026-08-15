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
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func chip(for item: QuoteCategory?) -> some View {
        let isSelected = selectedCategory == item
        let locked = item.map(isLocked) ?? false

        Button {
            if locked, let item {
                onLockedCategoryTap(item)
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
