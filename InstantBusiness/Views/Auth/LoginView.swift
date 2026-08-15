import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        VStack(spacing: 24) {
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
                    .frame(width: 120, height: 120)
                    .shadow(color: .orange.opacity(0.4), radius: 24, y: 12)
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Connecte-toi")
                    .font(.title.weight(.bold))
                Text("Pour sauvegarder tes favoris et ta série, quel que soit l'appareil.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    authManager.appleRequest(request)
                } onCompletion: { result in
                    authManager.handleAppleCompletion(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                GoogleSignInButton(scheme: .light, style: .wide) {
                    authManager.signInWithGoogle()
                }
                .frame(height: 50)

                if authManager.isLoading {
                    ProgressView()
                        .padding(.top, 4)
                }

                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
