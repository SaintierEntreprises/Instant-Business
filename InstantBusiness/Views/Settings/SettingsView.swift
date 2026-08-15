import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @StateObject private var notificationManager = NotificationManager()
    @State private var notificationsEnabled = SharedDefaults.notificationsEnabled
    @State private var notificationTime = SettingsView.time(
        hour: SharedDefaults.notificationHour,
        minute: SharedDefaults.notificationMinute
    )
    @State private var streak = SharedDefaults.streakCount
    @State private var showPaywall = false

    private static let defaultFreeHour = 8
    private static let defaultFreeMinute = 0

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

                Section("Notifications") {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack(spacing: 12) {
                            SettingsIconBadge(systemName: "bell.fill", color: .red)
                            Text("Citation quotidienne")
                        }
                    }
                    .onChange(of: notificationsEnabled) { _, newValue in
                        Task {
                            if newValue {
                                let hour = store.isPremium
                                    ? Calendar.current.component(.hour, from: notificationTime)
                                    : Self.defaultFreeHour
                                let minute = store.isPremium
                                    ? Calendar.current.component(.minute, from: notificationTime)
                                    : Self.defaultFreeMinute
                                await notificationManager.enable(hour: hour, minute: minute)
                                notificationsEnabled = SharedDefaults.notificationsEnabled
                            } else {
                                notificationManager.disable()
                            }
                        }
                    }

                    if notificationsEnabled {
                        if store.isPremium {
                            DatePicker(selection: $notificationTime, displayedComponents: .hourAndMinute) {
                                HStack(spacing: 12) {
                                    SettingsIconBadge(systemName: "clock.fill", color: .indigo)
                                    Text("Heure")
                                }
                            }
                            .onChange(of: notificationTime) { _, newValue in
                                Task {
                                    await notificationManager.enable(
                                        hour: Calendar.current.component(.hour, from: newValue),
                                        minute: Calendar.current.component(.minute, from: newValue)
                                    )
                                }
                            }
                        } else {
                            HStack {
                                HStack(spacing: 12) {
                                    SettingsIconBadge(systemName: "clock.fill", color: .indigo)
                                    Text("Heure")
                                }
                                Spacer()
                                Text("8h00")
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                showPaywall = true
                            } label: {
                                Label("Choisir l'heure avec Premium", systemImage: "lock.fill")
                                    .font(.footnote)
                            }
                        }
                    }
                }

                Section("Abonnement") {
                    if store.isPremium {
                        HStack(spacing: 12) {
                            SettingsIconBadge(systemName: "crown.fill", color: .yellow)
                            Text("Premium actif")
                                .fontWeight(.semibold)
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
            }
            .navigationTitle("Réglages")
            .onAppear { streak = SharedDefaults.streakCount }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private static func time(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
}
