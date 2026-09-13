import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var serverURL: String = ""

    var body: some View {
        Form {
            Section(String(localized: "server")) {
                TextField(String(localized: "server_url"), text: $serverURL, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                HStack {
                    Button(String(localized: "save_server")) { Task { await saveServer() } }
                    Button(String(localized: "test_connection")) { Task { await appState.testConnection() } }
                }
            } footer: {
                Text(String(localized: "server_url_help"))
            }

            Section(String(localized: "appearance")) {
                Picker(String(localized: "language"), selection: $appState.settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Picker(String(localized: "theme"), selection: $appState.settings.theme) {
                    Text(String(localized: "system")).tag(AppTheme.system)
                    Text(String(localized: "light")).tag(AppTheme.light)
                    Text(String(localized: "dark")).tag(AppTheme.dark)
                }
            }

            Section(String(localized: "account")) {
                LabeledContent(String(localized: "account"), value: appState.user?.displayName ?? appState.user?.username ?? "")
                Button(String(localized: "sign_out"), role: .destructive) { Task { await appState.logout() } }
            }

            Section(String(localized: "offline_workflow")) {
                Text(String(localized: "offline_workflow_body"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(localized: "offline_tip"))
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .navigationTitle(String(localized: "settings"))
        .onAppear { serverURL = appState.settings.serverURL }
        .alert(String(localized: "error"), isPresented: errorBinding()) {
            Button(String(localized: "ok"), role: .cancel) { appState.lastError = nil }
        } message: {
            Text(appState.lastError ?? "")
        }
    }

    private func saveServer() async {
        do {
            try appState.configure(serverURL: serverURL)
            await appState.testConnection()
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private func errorBinding() -> Binding<Bool> {
        Binding(get: { appState.lastError != nil }, set: { if !$0 { appState.lastError = nil } })
    }
}
