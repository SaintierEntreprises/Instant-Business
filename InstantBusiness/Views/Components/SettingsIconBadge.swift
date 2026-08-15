import SwiftUI

/// Small colored rounded-square icon badge, matching the visual language of Apple's own Settings app.
struct SettingsIconBadge: View {
    let systemName: String
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.gradient)
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
    }
}
