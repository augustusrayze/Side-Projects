import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Notifications
                Section {
                    HStack {
                        Label("Daily Notifications", systemImage: "bell.fill")
                            .foregroundStyle(Color.inkBrown)
                        Spacer()
                        Text(viewModel.notificationsEnabled ? "On" : "Off")
                            .font(.saintCaption)
                            .foregroundStyle(viewModel.notificationsEnabled ? Color.ancientGold : Color.inkBrown.opacity(0.4))
                    }

                    if !viewModel.notificationsEnabled {
                        Button {
                            Task { await viewModel.requestNotificationPermission() }
                        } label: {
                            Label("Enable Notifications", systemImage: "bell.badge")
                                .foregroundStyle(Color.ancientGold)
                        }
                    }

                    Button {
                        viewModel.openSystemSettings()
                    } label: {
                        Label("Open System Settings", systemImage: "gearshape")
                            .foregroundStyle(Color.inkBrown)
                    }
                } header: {
                    Text("Notifications")
                        .font(.saintCaption)
                        .foregroundStyle(Color.inkBrown.opacity(0.6))
                }

                // About
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                            .foregroundStyle(Color.inkBrown)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .font(.saintCaption)
                            .foregroundStyle(Color.inkBrown.opacity(0.5))
                    }

                    if let vaticanURL = URL(string: "https://www.vaticannews.va/en/saints.html") {
                        Link(destination: vaticanURL) {
                            Label("Feast Day Source: Vatican News", systemImage: "cross")
                                .foregroundStyle(Color.inkBrown)
                        }
                    }

                    if let wikiURL = URL(string: "https://en.wikipedia.org") {
                        Link(destination: wikiURL) {
                            Label("Content: Wikipedia (CC BY-SA 4.0)", systemImage: "link")
                                .foregroundStyle(Color.inkBrown)
                        }
                    }
                } header: {
                    Text("About")
                        .font(.saintCaption)
                        .foregroundStyle(Color.inkBrown.opacity(0.6))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.parchment.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            await viewModel.checkNotificationStatus()
        }
    }
}
