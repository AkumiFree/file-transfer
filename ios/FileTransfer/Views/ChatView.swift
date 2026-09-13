import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            if appState.friends.isEmpty {
                EmptyState(systemImage: "message", title: String(localized: "no_friends"), subtitle: String(localized: "chat_requires_friend"))
                    .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(appState.friends) { friend in
                        NavigationLink {
                            ChatConversationView(friend: friend)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(friend.online ? Color.green : Color.gray)
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName).font(.body.weight(.semibold))
                                    Text(lastMessage(for: friend) ?? String(localized: "start_conversation"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if friend.online {
                                    Text(String(localized: "online")).font(.caption).foregroundStyle(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text(String(localized: "conversations"))
                }
            }
        }
        .navigationTitle(String(localized: "chat"))
        .task { await appState.loadFriends() }
        .navigationDestination(for: Friend.self) { friend in
            ChatConversationView(friend: friend)
        }
    }

    private func lastMessage(for friend: Friend) -> String? {
        appState.conversations[friend.numericId]?.last?.body
    }
}

struct ChatConversationView: View {
    @EnvironmentObject private var appState: AppState
    let friend: Friend
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if let messages = appState.conversations[friend.numericId], !messages.isEmpty {
                            ForEach(messages) { message in
                                MessageBubble(message: message, outgoing: message.isOutgoing(for: appState.user?.numericId ?? -1))
                                    .id(message.id)
                            }
                        } else {
                            EmptyState(systemImage: "bubble.left", title: String(localized: "no_messages"), subtitle: String(localized: "no_messages_hint"))
                                .listRowBackground(Color.clear)
                                .padding(.top, 32)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .onChange(of: appState.conversations[friend.numericId]?.last?.id) { id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                }
            }
            composer
        }
        .navigationTitle(friend.displayName)
        .task { await appState.loadConversation(friend) }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField(String(localized: "message_placeholder"), text: $draft, axis: .vertical)
                .focused($isFocused)
                .onSubmit { send() }
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
            Button(action: send) {
                Image(systemName: "paperplane")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel(String(localized: "send"))
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || appState.isBusy)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func send() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        draft = ""
        Task { await appState.sendMessage(to: friend, content: content) }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let outgoing: Bool

    var body: some View {
        VStack(alignment: outgoing ? .trailing : .leading, spacing: 4) {
            Text(message.body)
                .font(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(outgoing ? Color.blue.opacity(0.9) : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(outgoing ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxWidth: .infinity, alignment: outgoing ? .trailing : .leading)
            Text(message.readAt != nil ? String(localized: "read") : String(localized: "sent"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityLabel(message.readAt != nil ? String(localized: "read") : String(localized: "sent"))
        }
        .frame(maxWidth: .infinity, alignment: outgoing ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: NSLocalizedString("message_accessibility", comment: ""), arguments: [message.body]))
    }
}
