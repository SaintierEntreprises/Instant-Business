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

    private var currentAppleNonce: String?

    override init() {
        super.init()
        observeAuthChanges()
    }

    private func observeAuthChanges() {
        Task {
            for await (_, session) in SupabaseProvider.client.auth.authStateChanges {
                self.session = session
            }
        }
    }

    // MARK: - Apple

    func appleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
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
            Task { await signIn(provider: .apple, idToken: identityToken, nonce: nonce) }
        case .failure(let error):
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
                await self.signIn(provider: .google, idToken: idToken, nonce: nil)
            }
        }
    }

    // MARK: - Shared

    private func signIn(provider: OpenIDConnectCredentials.Provider, idToken: String, nonce: String?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await SupabaseProvider.client.auth.signInWithIdToken(
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
