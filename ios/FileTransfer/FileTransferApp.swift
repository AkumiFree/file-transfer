import SwiftUI

@main
struct FileTransferApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .preferredColorScheme(appState.settings.theme.colorScheme)
        .environment(\.locale, Locale(identifier: appState.settings.language.localeIdentifier))
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: Tab = .home

    enum Tab: String, CaseIterable, Hashable {
        case home
        case friends
        case chat
        case files
        case transfers
        case settings
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView() }
                .tabItem { Label(String(localized: "tab_home"), systemImage: "house") }
                .tag(Tab.home)
            NavigationStack { FriendsView() }
                .tabItem { Label(String(localized: "tab_friends"), systemImage: "person.2") }
                .tag(Tab.friends)
            NavigationStack { ChatView() }
                .tabItem { Label(String(localized: "tab_chat"), systemImage: "message") }
                .tag(Tab.chat)
            NavigationStack { FilesView() }
                .tabItem { Label(String(localized: "tab_files"), systemImage: "folder") }
                .tag(Tab.files)
            NavigationStack { TransfersView() }
                .tabItem { Label(String(localized: "tab_transfers"), systemImage: "arrow.up.arrow.down") }
                .tag(Tab.transfers)
            NavigationStack { SettingsView() }
                .tabItem { Label(String(localized: "tab_settings"), systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(.blue)
    }
}
