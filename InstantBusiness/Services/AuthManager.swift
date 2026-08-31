import Foundation
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import Supabase
import UIKit

@MainActor
final class AuthManager: NSObject, ObservableObject {
    @Published private(set) var session: Session?
    @Published var errorMessage: String?
    @Published var isLoading = false

    /// True until Supabase has restored (or ruled out) a stored session. Without this the
    /// app would briefly consider the user signed out and flash the login screen on launch.
    @Published private(set) var isRestoringSession = true

    private var currentAppleNonce: String?

    override init() {
        super.init()
        observeAuthChanges()
    }

    private func observeAuthChanges() {
        Task {
            for await (_, session) in SupabaseProvider.client.auth.authStateChanges {
                self.session = session
                // Recopié pour les services et les vues qui n'ont pas accès à
                // l'environnement SwiftUI, notamment l'envoi des réglages.
                AuthSession.currentUserID = session?.user.id.uuidString
                self.isRestoringSession = false
            }
        }
        // Safety net: never leave the app stuck on the splash if no event ever arrives.
        Task {
            try? await Task.sleep(for: .seconds(3))
            self.isRestoringSession = false
        }
    }

    // MARK: - Apple

    func appleRequest(_ request: ASAuthorizationAppleIDRequest) {
        // SwiftUI can rebuild SignInWithAppleButton — and re-run this closure — between the
        // request and Apple's callback. Generating a fresh nonce each time would leave us
        // unable to match the token we get back, so an in-flight nonce is reused and only
        // cleared once the attempt finishes.
        let nonce = currentAppleNonce ?? Self.randomNonceString()
        currentAppleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityTokenData = credential.identityToken,
                let identityToken = String(data: identityTokenData, encoding: .utf8),
                let nonce = currentAppleNonce
            else {
                errorMessage = "Connexion Apple invalide."
                return
            }
            currentAppleNonce = nil
            Task { await signIn(provider: .apple, idToken: identityToken, nonce: nonce) }
        case .failure(let error):
            currentAppleNonce = nil
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "La connexion Apple a échoué."
            }
        }
    }

    // MARK: - Google

    func signInWithGoogle() {
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController
        else { return }

        isLoading = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                self.isLoading = false
                if let error {
                    if (error as NSError).code != GIDSignInError.canceled.rawValue {
                        self.errorMessage = "La connexion Google a échoué."
                    }
                    return
                }
                guard let idToken = result?.user.idToken?.tokenString else {
                    self.errorMessage = "Connexion Google invalide."
                    return
                }
                // Le SDK Google place son propre nonce dans le jeton, que l'app ne peut
                // pas reproduire ; la vérification du nonce est donc désactivée côté
                // Supabase pour ce fournisseur (le jeton reste validé : signature,
                // audience et expiration).
                await self.signIn(provider: .google, idToken: idToken, nonce: nil)
            }
        }
    }

    // MARK: - Shared

    private func signIn(provider: OpenIDConnectCredentials.Provider, idToken: String, nonce: String?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // La session est appliquée directement plutôt que d'attendre le flux
            // authStateChanges : si celui-ci tarde ou n'émet pas, l'utilisateur resterait
            // sur l'écran de connexion alors qu'il est authentifié.
            session = try await SupabaseProvider.client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: provider, idToken: idToken, nonce: nonce)
            )
            errorMessage = nil
        } catch {
            errorMessage = "La connexion a échoué. Réessaie."
        }
    }

    func signOut() async {
        try? await SupabaseProvider.client.auth.signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// Permanently deletes the account: server-side row (favorites/streak cascade
    /// automatically), then clears every local trace of it on this device.
    func deleteAccount() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await SupabaseProvider.client.functions.invoke("delete-account")
        } catch {
            errorMessage = "La suppression du compte a échoué. Réessaie."
            return false
        }
        try? await SupabaseProvider.client.auth.signOut()
        GIDSignIn.sharedInstance.signOut()
        SharedDefaults.resetAccountData()
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "hasCompletedProfile")
        UserDefaults.standard.removeObject(forKey: "hasCompletedQuiz")
        errorMessage = nil
        return true
    }

    // MARK: - Nonce helpers (Sign in with Apple replay protection)

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            fatalError("Impossible de générer un nonce sécurisé (\(status)).")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
