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
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("Série actuelle")
                        Spacer()
                        Text("\(streak) jour\(streak > 1 ? "s" : "")")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notifications") {
                    Toggle("Citation quotidienne", isOn: $notificationsEnabled)
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
                            DatePicker("Heure", selection: $notificationTime, displayedComponents: .hourAndMinute)
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
                                Text("Heure")
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
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Premium actif")
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Text("Passer à Instant Business Premium")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
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
