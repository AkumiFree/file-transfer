import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings {
        didSet { saveSettings() }
    }
    @Published private(set) var session: StoredSession?
    @Published private(set) var user: User?
    @Published private(set) var apiClient: APIClient?
    @Published private(set) var websocket: WebSocketClient?
    @Published private(set) var transferService: TransferService?
    @Published private(set) var localFiles: LocalFileStore
    @Published private(set) var health: HealthStatus?
    @Published private(set) var friends: [Friend] = []
    @Published private(set) var friendRequests: [FriendRequestRecord] = []
    @Published private(set) var searchResults: [SearchUser] = []
    @Published private(set) var conversations: [Int: [ChatMessage]] = [:]
    @Published var selectedFriendID: Int?
    @Published private(set) var transfers: [Transfer] = []
    @Published private(set) var lastError: String?
    @Published private(set) var isBusy = false

    private let keychain = KeychainStore()
    private lazy var defaults = UserDefaults.standard
    private var localFilesCancellable: AnyCancellable?
    private var transferServiceCancellable: AnyCancellable?

    init() {
        settings = Self.loadSettings()
        localFiles = LocalFileStore()
        localFilesCancellable = localFiles.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        restoreSession()
    }

    var isAuthenticated: Bool { session != nil && user != nil }

    func configure(serverURL: String) throws {
        websocket?.disconnect()
        let endpoints = try EndpointResolver.resolve(input: serverURL)
        let client = APIClient(endpoints: endpoints, keychain: keychain)
        client.sessionDidChange = { [weak self] updated in
            Task { @MainActor in self?.applySession(updated) }
        }
        let socket = WebSocketClient(endpoints: endpoints, keychain: keychain)
        socket.eventHandler = { [weak self] event in
            Task { @MainActor in self?.handleWebSocket(event) }
        }
        apiClient = client
        websocket = socket
        let service = TransferService(api: client)
        transferService = service
        bindTransferService(service)
        save(serverURL: serverURL)
        if session != nil {
            socket.connect()
            Task { await self.loadDashboard() }
        }
    }

    func restoreSession() {
        guard let stored = try? keychain.current() else { return }
        applySession(stored)
        if settings.serverURL.isEmpty { return }
        do {
            try configure(serverURL: settings.serverURL)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func login(identifier: String, password: String) async {
        await run {
            let endpoints = try EndpointResolver.resolve(input: self.settings.serverURL)
            let client = APIClient(endpoints: endpoints, keychain: self.keychain)
            let stored = try await client.login(identifier: identifier, password: password)
            self.applySession(stored)
            try await self.configureClient(client, endpoints: endpoints)
            await self.loadDashboard()
        }
    }

    func register(username: String, email: String?, displayName: String, password: String) async {
        await run {
            let endpoints = try EndpointResolver.resolve(input: self.settings.serverURL)
            let client = APIClient(endpoints: endpoints, keychain: self.keychain)
            let stored = try await client.register(username: username, email: email, displayName: displayName, password: password)
            self.applySession(stored)
            try await self.configureClient(client, endpoints: endpoints)
            await self.loadDashboard()
        }
    }

    func logout() async {
        websocket?.disconnect()
        if let client = apiClient {
            do { try await client.logout() } catch { }
        }
        try? keychain.delete()
        session = nil
        user = nil
        friends = []
        friendRequests = []
        conversations = [:]
        transfers = []
        searchResults = []
        selectedFriendID = nil
        health = nil
        apiClient = nil
        websocket = nil
        transferService = nil
        transferServiceCancellable = nil
    }

    func testConnection() async {
        await run {
            guard let client = self.apiClient else { throw APIError.invalidURL }
            self.health = try await client.health()
        }
    }

    func loadDashboard() async {
        await run {
            guard let client = self.apiClient else { return }
            do { self.health = try await client.health() } catch { }
            await self.loadFriends()
            await self.loadRequests()
            await self.loadTransfers()
            do { _ = try await client.unreadCount() } catch { }
        }
    }

    func loadFriends() async {
        await run {
            guard let client = self.apiClient else { return }
            let friends = try await client.friends()
            let presence = try await client.presence()
            let online = Set(presence.filter(\.online).map(\.numericId))
            self.friends = friends.map { friend in
                var updated = friend
                updated.online = online.contains(updated.numericId)
                return updated
            }
        }
    }

    func loadRequests() async {
        await run {
            guard let client = self.apiClient else { return }
            self.friendRequests = try await client.friendRequests()
        }
    }

    func searchFriends(query: String) async {
        await run {
            guard let client = self.apiClient else { return }
            self.searchResults = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : try await client.searchFriends(query: query)
        }
    }

    func sendFriendRequest(userID: Int) async {
        await run {
            guard let client = self.apiClient else { return }
            _ = try await client.sendFriendRequest(userID: userID)
            await self.loadRequests()
        }
    }

    func acceptFriendRequest(_ request: FriendRequestRecord) async {
        await run {
            guard let client = self.apiClient else { return }
            _ = try await client.acceptFriendRequest(requesterID: request.requesterId)
            await self.loadRequests()
            await self.loadFriends()
        }
    }

    func rejectFriendRequest(_ request: FriendRequestRecord) async {
        await run {
            guard let client = self.apiClient else { return }
            try await client.rejectFriendRequest(requesterID: request.requesterId)
            await self.loadRequests()
        }
    }

    func removeFriend(_ friend: Friend) async {
        await run {
            guard let client = self.apiClient else { return }
            try await client.removeFriend(userID: friend.numericId)
            await self.loadFriends()
        }
    }

    func block(_ friend: Friend) async {
        await run {
            guard let client = self.apiClient else { return }
            try await client.block(userID: friend.numericId)
            await self.loadFriends()
        }
    }

    func loadConversation(_ friend: Friend) async {
        selectedFriendID = friend.numericId
        await run {
            guard let client = self.apiClient else { return }
            let messages = try await client.chatHistory(userID: friend.numericId)
            self.conversations[friend.numericId] = messages
            _ = try await client.markConversationRead(userID: friend.numericId)
        }
    }

    func sendMessage(to friend: Friend, content: String) async {
        await run {
            guard let client = self.apiClient else { return }
            let message = try await client.sendMessage(recipientID: friend.numericId, content: content, clientMessageID: UUID().uuidString)
            self.append(message, for: friend.numericId)
        }
    }

    func markRead(_ message: ChatMessage, friend: Friend) async {
        guard let client = apiClient else { return }
        do {
            let updated = try await client.markMessageRead(messageID: Int(message.id) ?? 0)
            append(updated, for: friend.numericId)
        } catch { }
    }

    func loadTransfers() async {
        await run {
            guard let client = self.apiClient else { return }
            self.transfers = try await client.transfers()
            if let service = self.transferService {
                for transfer in self.transfers where transfer.status == .uploading {
                    try? await service.restoreProgress(for: transfer)
                }
            }
        }
    }

    func upload(_ item: LocalFileItem, to friend: Friend) async {
        await run {
            guard let service = self.transferService else { return }
            let transfer = try await service.upload(file: item, recipient: friend)
            self.upsert(transfer)
        }
    }

    func download(_ transfer: Transfer) async -> URL? {
        do {
            guard let service = transferService else { throw APIError.invalidURL }
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            let destination = directory.appendingPathComponent(transfer.filename)
            try await service.download(transfer: transfer, destinationURL: destination)
            upsert(transfer)
            return destination
        } catch is CancellationError {
            return nil
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func cancel(_ transfer: Transfer) async {
        await run {
            guard let service = self.transferService else { return }
            try await service.cancel(transferID: transfer.id)
            self.transfers.removeAll { $0.id == transfer.id }
        }
    }

    func importFiles(_ urls: [URL]) {
        do {
            _ = try localFiles.importFiles(from: urls)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteLocalFile(_ item: LocalFileItem) {
        do { try localFiles.delete(item) }
        catch { lastError = error.localizedDescription }
    }

    func save(serverURL: String) {
        settings.serverURL = serverURL
    }

    func saveSettings() {
        defaults.set(settings.language.rawValue, forKey: "language")
        defaults.set(settings.theme.rawValue, forKey: "theme")
        defaults.set(settings.serverURL, forKey: "serverURL")
    }

    private func bindTransferService(_ service: TransferService) {
        transferServiceCancellable = service.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    private func configureClient(_ client: APIClient, endpoints: ServerEndpoints) async throws {
        client.sessionDidChange = { [weak self] updated in
            Task { @MainActor in self?.applySession(updated) }
        }
        let socket = WebSocketClient(endpoints: endpoints, keychain: keychain)
        socket.eventHandler = { [weak self] event in
            Task { @MainActor in self?.handleWebSocket(event) }
        }
        apiClient = client
        websocket = socket
        let service = TransferService(api: client)
        transferService = service
        bindTransferService(service)
        socket.connect()
    }

    private func applySession(_ stored: StoredSession) {
        session = stored
        user = stored.user
    }

    private func handleWebSocket(_ event: WebSocketEvent) {
        switch event.type {
        case "chat.message":
            if let message: ChatMessage = event.data?.decoded(as: ChatMessage.self), let userID = user?.numericId {
                let peer = message.senderNumericId == userID ? message.recipientNumericId : message.senderNumericId
                append(message, for: peer)
            }
        case "chat.read":
            if let message: ChatMessage = event.data?.decoded(as: ChatMessage.self), let userID = user?.numericId {
                let peer = message.senderNumericId == userID ? message.recipientNumericId : message.senderNumericId
                append(message, for: peer)
            }
        case "presence":
            if let record: PresenceEvent = event.data?.decoded(as: PresenceEvent.self) {
                friends = friends.map { friend in
                    var updated = friend
                    if updated.numericId == record.userId { updated.online = record.online }
                    return updated
                }
            }
        case "transfer.status":
            if let transfer: Transfer = event.data?.decoded(as: Transfer.self) { upsert(transfer) }
        case "error":
            lastError = event.error?.message
        default: break
        }
    }

    private func append(_ message: ChatMessage, for peerID: Int) {
        var messages = conversations[peerID] ?? []
        if !messages.contains(where: { $0.id == message.id }) { messages.append(message) }
        messages.sort { $0.createdAt < $1.createdAt }
        conversations[peerID] = messages
    }

    private func upsert(_ transfer: Transfer) {
        if let index = transfers.firstIndex(where: { $0.id == transfer.id }) {
            transfers[index] = transfer
        } else {
            transfers.append(transfer)
        }
        transfers.sort { $0.createdAt > $1.createdAt }
    }

    private func run(_ work: @escaping () async throws -> Void) async {
        isBusy = true
        defer { isBusy = false }
        do { try await work() }
        catch is CancellationError { }
        catch { lastError = error.localizedDescription }
    }

    private static func loadSettings() -> AppSettings {
        let defaults = UserDefaults.standard
        return AppSettings(
            serverURL: defaults.string(forKey: "serverURL") ?? "",
            language: AppLanguage(rawValue: defaults.string(forKey: "language") ?? "") ?? .system,
            theme: AppTheme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        )
    }
}
