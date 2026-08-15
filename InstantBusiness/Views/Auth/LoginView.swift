import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var legalDocument: LegalDocument?

    private let buttonHeight: CGFloat = 54
    private let buttonRadius: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 108, height: 108)
                    .shadow(color: .orange.opacity(0.35), radius: 24, y: 12)
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }

            Text("Connecte-toi")
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .padding(.top, 28)

            Text("Pour garder tes favoris et ta série,\nsur tous tes appareils.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue) { request in
                    authManager.appleRequest(request)
                } onCompletion: { result in
                    authManager.handleAppleCompletion(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: buttonHeight)
                .clipShape(RoundedRectangle(cornerRadius: buttonRadius, style: .continuous))

                GoogleSignInButtonView(height: buttonHeight, cornerRadius: buttonRadius) {
                    authManager.signInWithGoogle()
                }
                .disabled(authManager.isLoading)

                ZStack {
                    if authManager.isLoading {
                        ProgressView()
                    } else if let errorMessage = authManager.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(height: 24)

                VStack(spacing: 2) {
                    Text("En continuant, tu acceptes nos")
                    HStack(spacing: 4) {
                        Button("CGU") { legalDocument = .termsOfUse }
                        Text("et notre")
                        Button("Politique de confidentialité") { legalDocument = .privacyPolicy }
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(item: $legalDocument) { document in
            NavigationStack {
                LegalDocumentView(document: document)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") { legalDocument = nil }
                        }
                    }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
