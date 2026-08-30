import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var appearance: AppearanceStore
    @Environment(\.openURL) private var openURL
    @State private var showThemePicker = false
    @StateObject private var notificationManager = NotificationManager()
    @State private var notificationsEnabled = SharedDefaults.notificationsEnabled
    @State private var frequency = SharedDefaults.notificationFrequency

    /// Voir `CardFeedView` : recopier la valeur dans un `@State` à l'apparition affichait
    /// une série périmée, la synchronisation serveur arrivant après.
    @AppStorage(SharedDefaults.streakCountKey, store: SharedDefaults.suite)
    private var streak = 0
    @AppStorage(SharedDefaults.bestStreakKey, store: SharedDefaults.suite)
    private var bestStreak = 0
    @State private var showStreakDetail = false
    @State private var showPaywall = false
    @State private var isSigningOut = false
    @State private var isDeletingAccount = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        Haptics.tap()
                        showStreakDetail = true
                    } label: {
                        streakCard
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.98))
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section {
                    Picker(selection: $appearance.appTheme) {
                        ForEach(AppTheme.allCases) { option in
                            Label(option.displayName, systemImage: option.icon).tag(option)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIconBadge(systemName: "moon.fill", color: .indigo)
                            Text("Mode nuit")
                        }
                    }
                    .onChange(of: appearance.appTheme) { _, newValue in
                        Haptics.select()
                        Analytics.track(.appThemeChanged, ["theme": .string(newValue.rawValue)])
                    }

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
                    // Sans style explicite, un bouton de formulaire teinte toute son
                    // étiquette avec la couleur d'accent : `.primary` et `.secondary` sont
                    // des styles hiérarchiques, ils se résolvent contre la teinte
                    // ambiante. La ligne s'affichait donc en orange à côté de voisines
                    // noires, comme si elle était active.
                    .buttonStyle(.plain)
                } header: {
                    Text("Apparence")
                } footer: {
                    Text(appearance.appTheme == .system
                         ? "L'app suit le réglage clair/sombre d'iOS."
                         : "L'app reste en \(appearance.appTheme.displayName.lowercased()), quel que soit le réglage d'iOS.")
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
                                Analytics.track(
                                    notificationsEnabled ? .notificationsEnabled : .notificationsDisabled,
                                    ["granted": .bool(notificationsEnabled)]
                                )
                            } else {
                                notificationManager.disable()
                                Analytics.track(.notificationsDisabled, ["granted": .bool(false)])
                            }
                        }
                    }
                    if notificationsEnabled {
                        Picker(selection: $frequency) {
                            ForEach(NotificationFrequency.allCases) { option in
                                Text("\(option.displayName) — \(option.summary)").tag(option)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                SettingsIconBadge(systemName: "slider.horizontal.3", color: .orange)
                                Text("Rythme")
                            }
                        }
                        .onChange(of: frequency) { _, newValue in
                            SharedDefaults.notificationFrequency = newValue
                            Analytics.track(.notificationFrequencyChanged, [
                                "frequency": .string(newValue.rawValue),
                                "per_day": .int(newValue.perDay)
                            ])
                            // Reprogrammation immédiate : sans elle, l'ancien rythme
                            // resterait en vigueur jusqu'au prochain retour au premier plan.
                            Task { await notificationManager.reschedule() }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(notificationsEnabled
                         ? "\(frequency.summary), toujours entre 8h et 21h — synchronisées avec ce que montre ton widget. Plus un rappel à 18h les jours où tu n'as pas encore ouvert l'app, pour ne pas perdre ta série."
                         : "Active les notifications pour recevoir tes citations dans la journée.")
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

                Section {
                    Button {
                        Haptics.tap()
                        Analytics.track(.reviewLinkOpened)
                        if let url = ReviewPrompter.writeReviewURL {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            SettingsIconBadge(systemName: "star.fill", color: .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Noter Instant Business")
                                    .fontWeight(.semibold)
                                Text("Une note aide vraiment une app indépendante")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    // Même raison que la ligne « Thème des cartes » : sans style explicite,
                    // un bouton de formulaire teinte toute son étiquette en orange.
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
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
                PaywallView(origin: "settings")
            }
            .navigationDestination(isPresented: $showStreakDetail) {
                StreakDetailView()
            }
            .sheet(isPresented: $showThemePicker) {
                CardThemePickerView()
            }
            .alert("Supprimer définitivement ton compte ?", isPresented: $showDeleteConfirmation) {
                Button("Annuler", role: .cancel) {}
                Button("Supprimer", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        Analytics.track(.accountDeleted)
                        _ = await authManager.deleteAccount()
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text("Tes favoris, ta série et ton profil seront effacés définitivement. Cette action est irréversible.")
            }
        }
    }

    /// Recalculé à chaque rendu plutôt que figé dans un `@State` : la série arrive de la
    /// synchronisation après l'apparition de l'écran, et `streak` change alors — c'est ce
    /// changement qui redessine la semaine avec les bons jours.
    private var weekDays: [StreakDay] {
        StreakWeek.days(streak: streak, openDays: SharedDefaults.openDays, frozenDays: SharedDefaults.frozenDays)
    }

    /// La même semaine que dans la célébration, en plus discret.
    ///
    /// Le texte « X jours de suite » seul ne disait rien de ce qu'il fallait faire pour
    /// que le nombre monte, ni de ce qui restait à tenir. La carte reprend donc les deux
    /// repères de la sheet — la semaine et le palier suivant — pour qu'on les retrouve
    /// sans avoir à attendre une notification.
    private var streakCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(StreakPalette.flame)
                        .frame(width: 52, height: 52)
                        .shadow(color: StreakPalette.tint.opacity(0.35), radius: 8, y: 4)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(streak) jour\(streak > 1 ? "s" : "") de suite")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text(streakSubtitle)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            Divider()
                .opacity(0.4)

            StreakWeekTracker(days: weekDays, size: .compact)

            StreakMilestoneBar(streak: streak)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .animation(.spring(response: 0.45, dampingFraction: 1), value: streak)
    }

    private var streakSubtitle: String {
        guard streak > 0 else { return "Ouvre l'app chaque jour pour démarrer ta série" }
        if bestStreak > streak { return "Ton record : \(bestStreak) jours" }
        return "Ta meilleure série à ce jour"
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
        frequency = SharedDefaults.notificationFrequency
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
        .environmentObject(AuthManager())
        .environmentObject(AppearanceStore())
}
