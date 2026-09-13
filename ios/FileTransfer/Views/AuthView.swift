import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var serverURL: String = ""
    @State private var identifier: String = ""
    @State private var password: String = ""
    @State private var displayName: String = ""
    @State private var isRegistering = false
    @State private var configuredURL: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case serverURL
        case identifier
        case password
        case displayName
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "server_url"), text: $serverURL, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .focused($focusedField, equals: .serverURL)
                } footer: {
                    Text(String(localized: "server_url_help"))
                }

                Section {
                    Picker(String(localized: "account_mode"), selection: $isRegistering) {
                        Text(String(localized: "sign_in")).tag(false)
                        Text(String(localized: "create_account")).tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text(isRegistering ? String(localized: "create_account") : String(localized: "sign_in"))) {
                    TextField(String(localized: "identifier"), text: $identifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .identifier)
                    SecureField(String(localized: "password"), text: $password)
                        .focused($focusedField, equals: .password)
                    if isRegistering {
                        TextField(String(localized: "display_name"), text: $displayName)
                            .focused($focusedField, equals: .displayName)
                    }
                }

                Section {
                    Button(isRegistering ? String(localized: "create_account") : String(localized: "sign_in")) {
                        submit()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle(String(localized: "app_name"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(configuredURL.isEmpty ? String(localized: "save_server") : String(localized: "server_saved")) {
                        saveServer()
                    }
                    .disabled(serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if appState.isBusy { ProgressView() }
            }
            .alert(String(localized: "error"), isPresented: bindingToError()) {
                Button(String(localized: "ok"), role: .cancel) { appState.clearError() }
            } message: {
                Text(appState.lastError ?? "")
            }
        }
        .onAppear {
            serverURL = appState.settings.serverURL
            configuredURL = appState.settings.serverURL
            if !configuredURL.isEmpty { connectToServer() }
        }
    }

    private var canSubmit: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password.count >= 8 &&
        (!isRegistering || !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func saveServer() {
        do {
            try appState.configure(serverURL: serverURL)
            configuredURL = serverURL
            focusedField = .identifier
        } catch {
            appState.setError(error.localizedDescription)
        }
    }

    private func connectToServer() {
        serverURL = appState.settings.serverURL
        do {
            try appState.configure(serverURL: serverURL)
        } catch {
            appState.setError(error.localizedDescription)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        if isRegistering {
            Task { await appState.register(username: identifier, email: nil, displayName: displayName, password: password) }
        } else {
            Task { await appState.login(identifier: identifier, password: password) }
        }
    }

    private func bindingToError() -> Binding<Bool> {
        Binding(
            get: { appState.lastError != nil },
            set: { if !$0 { appState.clearError() } }
        )
    }
}
