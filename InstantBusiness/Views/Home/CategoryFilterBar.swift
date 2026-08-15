import SwiftUI

struct CategoryFilterBar: View {
    @EnvironmentObject private var store: StoreManager
    @Binding var selectedCategory: QuoteCategory?
    var onLockedCategoryTap: (QuoteCategory) -> Void = { _ in }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(title: "Tout", isSelected: selectedCategory == nil, isLocked: false) {
                    selectedCategory = nil
                }
                ForEach(QuoteCategory.allCases) { category in
                    let locked = isLocked(category)
                    chip(title: category.displayName, isSelected: selectedCategory == category, isLocked: locked) {
                        if locked {
                            onLockedCategoryTap(category)
                        } else {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func isLocked(_ category: QuoteCategory) -> Bool {
        category != .mindset && !store.isPremium
    }

    private func chip(title: String, isSelected: Bool, isLocked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
