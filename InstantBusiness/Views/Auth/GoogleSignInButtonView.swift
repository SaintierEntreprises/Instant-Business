import SwiftUI
import UIKit
import GoogleSignInSwift

/// A Google sign-in button laid out like Apple's (logo + label centred as one group).
///
/// The mark itself is the official one shipped inside the GoogleSignIn SDK's resource
/// bundle, so branding stays compliant. If that asset ever moves, this falls back to the
/// SDK's own button rather than drawing an approximated logo.
struct GoogleSignInButtonView: View {
    let height: CGFloat
    let cornerRadius: CGFloat
    let action: () -> Void

    private static let officialLogo: UIImage? = {
        guard
            let bundleURL = Bundle.main.url(forResource: "GoogleSignIn_GoogleSignIn", withExtension: "bundle"),
            let bundle = Bundle(url: bundleURL)
        else { return nil }
        return UIImage(named: "google", in: bundle, compatibleWith: nil)
    }()

    var body: some View {
        if let logo = Self.officialLogo {
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(uiImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    Text("Continuer avec Google")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.black.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(.white, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color(white: 0.85), lineWidth: 1)
                }
            }
            .buttonStyle(PressableButtonStyle(scale: 0.98))
        } else {
            GoogleSignInButton(scheme: .light, style: .wide, action: action)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
