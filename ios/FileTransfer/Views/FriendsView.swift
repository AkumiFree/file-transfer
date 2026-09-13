import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var tab: FriendsTab = .friends

    private enum FriendsTab: String, CaseIterable, Identifiable {
        case friends
        case requests
        case search

        var id: String { rawValue }

        var title: String {
            switch self {
            case .friends: return String(localized: "friends")
            case .requests: return String(localized: "requests")
            case .search: return String(localized: "search")
            }
        }
    }

    var body: some View {
        List {
            Picker(String(localized: "friends"), selection: $tab) {
                ForEach(FriendsTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch tab {
            case .friends:
                friendsSection
            case .requests:
                requestsSection
            case .search:
                searchSection
            }
        }
        .navigationTitle(String(localized: "friends"))
        .searchable(text: $query, prompt: String(localized: "search_friends_prompt"))
        .onChange(of: query) { newValue in
            if tab == .search { Task { await appState.searchFriends(query: newValue) } }
        }
        .task {
            await appState.loadFriends()
            await appState.loadRequests()
        }
        .overlay {
            if appState.isBusy { ProgressView() }
        }
        .alert(String(localized: "error"), isPresented: errorBinding()) {
            Button(String(localized: "ok"), role: .cancel) { appState.lastError = nil }
        } message: {
            Text(appState.lastError ?? "")
        }
    }

    private var friendsSection: some View {
        Group {
            if appState.friends.isEmpty {
                EmptyState(systemImage: "person.crop.circle.badge.plus", title: String(localized: "no_friends"), subtitle: String(localized: "no_friends_hint"))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(appState.friends) { friend in
                        NavigationLink {
                            ChatConversationView(friend: friend)
                        } label: {
                            FriendRow(friend: friend)
                        }
                        .accessibilityLabel(String(format: NSLocalizedString("message_friend_accessibility", comment: ""), arguments: [friend.displayName]))
                    }
                } header: {
                    Text(String(localized: "accepted_friends"))
                }
            }
        }
    }

    private var requestsSection: some View {
        Group {
            if appState.friendRequests.isEmpty {
                EmptyState(systemImage: "envelope.open", title: String(localized: "no_requests"), subtitle: String(localized: "no_requests_hint"))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(appState.friendRequests) { request in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(request.displayName).font(.headline)
                            Text(request.direction == .incoming ? String(localized: "incoming_request") : String(localized: "outgoing_request"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if request.direction == .incoming {
                                HStack {
                                    Button(String(localized: "accept")) { Task { await appState.acceptFriendRequest(request) } }
                                    Button(String(localized: "reject")) { Task { await appState.rejectFriendRequest(request) } }
                                }
                            } else {
                                Text(String(localized: "waiting_for_response")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var searchSection: some View {
        Section {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(String(localized: "search_friends_prompt"))
                    .foregroundStyle(.secondary)
            } else if appState.searchResults.isEmpty {
                Text(String(localized: "no_search_results")).foregroundStyle(.secondary)
            } else {
                ForEach(appState.searchResults) { user in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(user.displayName).font(.headline)
                        Text(user.username).font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Text(user.relationship.rawValue.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary)
                                .clipShape(Capsule())
                            if user.relationship == .none {
                                Button(String(localized: "send_request")) { Task { await appState.sendFriendRequest(userID: user.numericId) } }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text(String(localized: "search_results"))
        }
    }

    private func errorBinding() -> Binding<Bool> {
        Binding(get: { appState.lastError != nil }, set: { if !$0 { appState.lastError = nil } })
    }
}

private struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(friend.online ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
                .accessibilityLabel(friend.online ? String(localized: "online") : String(localized: "offline"))
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName).font(.body.weight(.semibold))
                Text(friend.username).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(text: friend.online ? String(localized: "online") : String(localized: "offline"), online: friend.online)
        }
        .padding(.vertical, 4)
    }
}
