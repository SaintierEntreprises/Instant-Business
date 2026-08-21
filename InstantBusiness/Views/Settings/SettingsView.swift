import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var appearance: AppearanceStore
    @State private var showThemePicker = false
    @StateObject private var notificationManager = NotificationManager()
    @State private var notificationsEnabled = SharedDefaults.notificationsEnabled

    /// Voir `CardFeedView` : recopier la valeur dans un `@State` à l'apparition affichait
    /// une série périmée, la synchronisation serveur arrivant après.
    @AppStorage(SharedDefaults.streakCountKey, store: SharedDefaults.suite)
    private var streak = 0
    @State private var showPaywall = false
    @State private var isSigningOut = false
    @State private var isDeletingAccount = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.orange, .red.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                                .frame(width: 56, height: 56)
                            Image(systemName: "flame.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(streak) jour\(streak > 1 ? "s" : "") de suite")
                                .font(.headline)
                            Text(streak > 0 ? "Continue comme ça !" : "Ouvre l'app chaque jour pour démarrer ta série")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }

                Section("Apparence") {
                    Button {
                        showThemePicker = true
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIconBadge(systemName: "paintpalette.fill", color: .pink)
                            Text("Thème des cartes")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(appearance.cardTheme.displayName)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack(spacing: 12) {
                            SettingsIconBadge(systemName: "bell.fill", color: .red)
                            Text("Citation quotidienne")
                        }
                    }
                    .onChange(of: notificationsEnabled) { _, newValue in
                        Task {
                            if newValue {
                                await notificationManager.enable()
                                notificationsEnabled = SharedDefaults.notificationsEnabled
                            } else {
                                notificationManager.disable()
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Ta citation du jour à minuit, plus une citation aléatoire toutes les 4h — synchronisée avec ce que montre ton widget.")
                }

                Section("Abonnement") {
                    if store.isPremium {
                        HStack(spacing: 12) {
                            SettingsIconBadge(systemName: "crown.fill", color: .yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.hasGrantedPremium ? "Premium offert" : "Premium actif")
                                    .fontWeight(.semibold)
                                if store.hasGrantedPremium {
                                    // Sans cette ligne, quelqu'un à qui l'accès a été
                                    // offert pourrait le croire facturé et chercher à
                                    // résilier un abonnement qui n'existe pas.
                                    Text("Accès accordé par Instant Business, rien ne t'est facturé.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 2)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                SettingsIconBadge(systemName: "crown.fill", color: .yellow)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Passer à Premium")
                                        .fontWeight(.semibold)
                                    Text("Toutes les catégories et thèmes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                    }
                }

                Section("Légal") {
                    ForEach(LegalDocument.allCases) { document in
                        NavigationLink {
                            LegalDocumentView(document: document)
                        } label: {
                            HStack(spacing: 12) {
                                SettingsIconBadge(systemName: document.icon, color: .gray)
                                Text(document.title)
                            }
                        }
                    }
                }

                Section("Compte") {
                    HStack(spacing: 12) {
                        SettingsIconBadge(systemName: "person.fill", color: .blue)
                        VStack(alignment: .leading, spacing: 2) {
                            if let name = fullName {
                                Text(name)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            }
                            Text(authManager.session?.user.email ?? "Connecté")
                                .font(fullName == nil ? .body : .caption)
                                .foregroundStyle(fullName == nil ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    Button(role: .destructive) {
                        Task {
                            isSigningOut = true
                            await authManager.signOut()
                            isSigningOut = false
                        }
                    } label: {
                        HStack {
                            Text("Se déconnecter")
                            Spacer()
                            if isSigningOut {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSigningOut)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Text("Supprimer mon compte")
                            Spacer()
                            if isDeletingAccount {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isDeletingAccount)
                }
            }
            .navigationTitle("Réglages")
            // Les notifications peuvent avoir été coupées depuis les réglages d'iOS : sans
            // cette relecture, l'interrupteur restait allumé alors que plus rien n'arrivait.
            .task { await refreshNotificationState() }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showThemePicker) {
                CardThemePickerView()
            }
            .alert("Supprimer définitivement ton compte ?", isPresented: $showDeleteConfirmation) {
                Button("Annuler", role: .cancel) {}
                Button("Supprimer", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        _ = await authManager.deleteAccount()
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text("Tes favoris, ta série et ton profil seront effacés définitivement. Cette action est irréversible.")
            }
        }
    }

    /// Le prénom et le nom saisis après la connexion, quand ils existent : l'adresse
    /// e-mail seule était peu parlante, surtout avec le relais « Masquer mon adresse ».
    private var fullName: String? {
        let parts = [SharedDefaults.firstName, SharedDefaults.lastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private func refreshNotificationState() async {
        let granted = await notificationManager.isSystemAuthorized()
        if !granted, SharedDefaults.notificationsEnabled {
            SharedDefaults.notificationsEnabled = false
        }
        notificationsEnabled = SharedDefaults.notificationsEnabled
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
        .environmentObject(AuthManager())
        .environmentObject(AppearanceStore())
}
