import SwiftUI

struct LegalDocumentView: View {
    let document: LegalDocument

    private var blocks: [String] {
        document.content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    render(block)
                }
            }
            .padding(20)
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func render(_ block: String) -> some View {
        if block.hasPrefix("# ") {
            Text(String(block.dropFirst(2)))
                .font(.system(.title2, design: .rounded, weight: .heavy))
        } else if block.hasPrefix("## ") {
            Text(String(block.dropFirst(3)))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 6)
        } else {
            Text(.init(block))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineSpacing(4)
        }
    }
}

#Preview {
    NavigationStack {
        LegalDocumentView(document: .privacyPolicy)
    }
}
