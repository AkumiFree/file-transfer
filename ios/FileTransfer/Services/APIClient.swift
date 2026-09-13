import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case network(String)
    case server(status: Int, code: String?, message: String?)
    case decoding(String)
    case emptyResponse
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL: return String(localized: "error_invalid_url")
        case .unauthorized: return String(localized: "error_unauthorized")
        case let .network(message): return message
        case let .server(_, code, message): return message ?? code ?? String(localized: "error_request_failed")
        case let .decoding(message): return message
        case .emptyResponse: return String(localized: "error_empty_response")
        case .cancelled: return String(localized: "error_cancelled")
        }
    }
}

final class APIClient {
    let endpoints: ServerEndpoints
    private let keychain: KeychainStore
    private let session: URLSession
    private let decoder = APIJSON.decoder()
    private let encoder = APIJSON.encoder()
    private let refreshCoordinator = RefreshCoordinator()
    var sessionDidChange: ((StoredSession) -> Void)?

    init(endpoints: ServerEndpoints, keychain: KeychainStore = KeychainStore(), session: URLSession = .shared) {
        self.endpoints = endpoints
        self.keychain = keychain
        self.session = session
    }

    func health() async throws -> HealthStatus {
        try await request(HealthStatus.self, endpoints.health, method: "GET", authenticated: false, retry: false)
    }

    func register(username: String?, email: String?, displayName: String?, password: String) async throws -> StoredSession {
        let body = RegisterRequest(
            username: username?.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email?.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        let response: AuthResponse = try await request(AuthResponse.self, url("auth/register"), method: "POST", body: body, authenticated: false, retry: false)
        let session = StoredSession(tokens: response.tokens, user: response.user)
        try keychain.save(session)
        sessionDidChange?(session)
        return session
    }

    func login(identifier: String, password: String) async throws -> StoredSession {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let isEmail = trimmed.contains("@")
        let body = LoginRequest(username: isEmail ? nil : trimmed, email: isEmail ? trimmed : nil, password: password)
        let response: AuthResponse = try await request(AuthResponse.self, url("auth/login"), method: "POST", body: body, authenticated: false, retry: false)
        let session = StoredSession(tokens: response.tokens, user: response.user)
        try keychain.save(session)
        sessionDidChange?(session)
        return session
    }

    func me() async throws -> User {
        let response: UserResponse = try await request(UserResponse.self, url("auth/me"), method: "GET")
        return response.user
    }

    func refreshSession() async throws -> StoredSession {
        try await refreshCoordinator.run { [weak self] in
            guard let self else { throw APIError.unauthorized }
            return try await self.rotateSession()
        }
    }

    private func rotateSession() async throws -> StoredSession {
        guard let current = try keychain.current() else { throw APIError.unauthorized }
        let body = RefreshRequest(refreshToken: current.tokens.refreshToken)
        let response: RefreshResponse = try await request(RefreshResponse.self, url("auth/refresh"), method: "POST", body: body, authenticated: false, retry: false)
        let updated = StoredSession(tokens: response.tokens, user: current.user)
        try keychain.save(updated)
        sessionDidChange?(updated)
        return updated
    }

    func logout() async throws {
        do {
            try await requestVoid(url("auth/logout"), method: "POST")
        } catch {
            try keychain.delete()
        }
        sessionDidChange?(StoredSession(tokens: AuthTokens(accessToken: "", refreshToken: "", accessExpiresAt: Date.distantPast, refreshExpiresAt: Date.distantPast, sessionId: ""), user: nil))
    }

    func searchFriends(query: String, limit: Int = 50) async throws -> [SearchUser] {
        var components = URLComponents(url: endpoints.friends.appendingPathComponent("search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: String(limit))]
        guard let url = components?.url else { throw APIError.invalidURL }
        let response: SearchUsersResponse = try await request(SearchUsersResponse.self, url, method: "GET")
        return response.users
    }

    func friends() async throws -> [Friend] {
        let response: FriendListResponse = try await request(FriendListResponse.self, url("friends"), method: "GET")
        return response.users
    }

    func presence() async throws -> [PresenceRecord] {
        let response: PresenceListResponse = try await request(PresenceListResponse.self, url("friends/presence"), method: "GET")
        return response.users
    }

    func friendRequests() async throws -> [FriendRequestRecord] {
        let response: FriendRequestListResponse = try await request(FriendRequestListResponse.self, url("friends/requests"), method: "GET")
        return response.requests
    }

    func sendFriendRequest(userID: Int) async throws -> FriendRequestRecord {
        let response: FriendRequestResponse = try await request(FriendRequestResponse.self, url("friends/requests/\(userID)"), method: "POST")
        return response.request
    }

    func acceptFriendRequest(requesterID: Int) async throws -> User {
        let response: UserResponse = try await request(UserResponse.self, url("friends/requests/\(requesterID)/accept"), method: "POST")
        return response.user
    }

    func rejectFriendRequest(requesterID: Int) async throws {
        try await requestVoid(url("friends/requests/\(requesterID)/reject"), method: "POST")
    }

    func removeFriend(userID: Int) async throws {
        try await requestVoid(url("friends/\(userID)"), method: "DELETE")
    }

    func block(userID: Int) async throws {
        try await requestVoid(url("friends/\(userID)/block"), method: "POST")
    }

    func unblock(userID: Int) async throws {
        try await requestVoid(url("friends/\(userID)/block"), method: "DELETE")
    }

    func chatHistory(userID: Int, before: Int? = nil, limit: Int = 50) async throws -> [ChatMessage] {
        var components = URLComponents(url: endpoints.chat.appendingPathComponent("history"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "userId", value: String(userID)), URLQueryItem(name: "limit", value: String(limit))]
        if let before { components?.queryItems?.append(URLQueryItem(name: "before", value: String(before))) }
        guard let url = components?.url else { throw APIError.invalidURL }
        let response: MessageListResponse = try await request(MessageListResponse.self, url, method: "GET")
        return response.messages
    }

    func sendMessage(recipientID: Int, content: String, clientMessageID: String? = nil) async throws -> ChatMessage {
        let body = SendMessageRequest(recipientId: recipientID, content: content, clientMessageId: clientMessageID)
        let response: MessageResponse = try await request(MessageResponse.self, url("chat/messages"), method: "POST", body: body)
        return response.message
    }

    func markMessageRead(messageID: Int) async throws -> ChatMessage {
        let response: MessageResponse = try await request(MessageResponse.self, url("chat/messages/\(messageID)/read"), method: "POST")
        return response.message
    }

    func markConversationRead(userID: Int) async throws -> Int {
        let response: ReadResponse = try await request(ReadResponse.self, url("chat/read/\(userID)"), method: "POST")
        return response.value
    }

    func unreadCount() async throws -> Int {
        let response: ReadResponse = try await request(ReadResponse.self, url("chat/unread"), method: "GET")
        return response.value
    }

    func transfers(status: TransferStatus? = nil) async throws -> [Transfer] {
        var target = endpoints.transfers
        if let status {
            var components = URLComponents(url: target, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "status", value: status.rawValue)]
            target = components?.url ?? target
        }
        let response: TransferListResponse = try await request(TransferListResponse.self, target, method: "GET")
        return response.transfers
    }

    func transfer(id: String) async throws -> Transfer {
        let response: TransferResponse = try await request(TransferResponse.self, url("transfers/\(id)"), method: "GET")
        return response.transfer
    }

    func transferChunks(id: String) async throws -> [TransferChunk] {
        let response: TransferChunksResponse = try await request(TransferChunksResponse.self, url("transfers/\(id)/chunks"), method: "GET")
        return response.chunks
    }

    func createTransfer(recipientID: Int, filename: String, size: Int64, sha256: String, chunkSize: Int64) async throws -> Transfer {
        let body = UploadCreationRequest(recipientId: recipientID, filename: filename, size: size, sha256: sha256, chunkSize: chunkSize)
        let response: TransferResponse = try await request(TransferResponse.self, url("transfers"), method: "POST", body: body)
        return response.transfer
    }

    func completeTransfer(id: String) async throws -> Transfer {
        let response: TransferResponse = try await request(TransferResponse.self, url("transfers/\(id)/complete"), method: "POST")
        return response.transfer
    }

    func cancelTransfer(id: String) async throws {
        try await requestVoid(url("transfers/\(id)"), method: "DELETE")
    }

    func uploadChunk(transferID: String, index: Int, data: Data, totalSize: Int64, chunkSize: Int64, sha256: String) async throws -> Transfer {
        let start = Int64(index) * chunkSize
        let end = start + Int64(data.count) - 1
        var request = URLRequest(url: url("transfers/\(transferID)/chunks/\(index)"))
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("bytes \(start)-\(end)/\(totalSize)", forHTTPHeaderField: "Content-Range")
        request.setValue(sha256, forHTTPHeaderField: "X-Chunk-SHA256")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        let response = try await perform(request, authenticated: true)
        guard let http = response.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw decodeError(response.0, status: (response.1 as? HTTPURLResponse)?.statusCode ?? 0) }
        let uploadResponse: UploadChunkResponse = try decoder.decode(UploadChunkResponse.self, from: response.0)
        return uploadResponse.transfer
    }

    func downloadChunk(transferID: String, start: Int64, end: Int64) async throws -> DownloadChunkResponse {
        var request = URLRequest(url: url("transfers/\(transferID)/download"))
        request.httpMethod = "GET"
        request.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
        let response = try await perform(request, authenticated: true)
        guard let http = response.1 as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw APIError.emptyResponse }
        return DownloadChunkResponse(data: response.0, contentRange: http.value(forHTTPHeaderField: "Content-Range"), etag: http.value(forHTTPHeaderField: "ETag"))
    }

    private func url(_ path: String) -> URL {
        URL(string: "\(endpoints.apiBase)/\(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))")!
    }

    private func request<T: Decodable>(_ type: T.Type, _ url: URL, method: String, body: (any Encodable)? = nil, headers: [String: String] = [:], authenticated: Bool = true, retry: Bool = true) async throws -> T {
        let response = try await perform(url, method: method, body: body, headers: headers, authenticated: authenticated, retry: retry)
        let data = response.0
        let http = response.1 as? HTTPURLResponse
        guard let statusCode = http?.statusCode else { throw APIError.emptyResponse }
        guard (200..<300).contains(statusCode) else { throw decodeError(data, status: statusCode) }
        guard !data.isEmpty else { throw APIError.emptyResponse }
        do { return try decoder.decode(type, from: data) }
        catch { throw APIError.decoding(error.localizedDescription) }
    }

    private func requestVoid(_ url: URL, method: String, body: (any Encodable)? = nil, headers: [String: String] = [:], authenticated: Bool = true, retry: Bool = true) async throws {
        let response = try await perform(url, method: method, body: body, headers: headers, authenticated: authenticated, retry: retry)
        let http = response.1 as? HTTPURLResponse
        guard let statusCode = http?.statusCode else { throw APIError.emptyResponse }
        guard (200..<300).contains(statusCode) else { throw decodeError(response.0, status: statusCode) }
    }

    private func perform(_ url: URL, method: String, body: (any Encodable)? = nil, headers: [String: String] = [:], authenticated: Bool, retry: Bool) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authenticated {
            guard let token = try keychain.current()?.tokens.accessToken, !token.isEmpty else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            var result = try await session.data(for: request)
            if let http = result.1 as? HTTPURLResponse, http.statusCode == 401 && authenticated && retry {
                _ = try await refreshSession()
                if let token = try keychain.current()?.tokens.accessToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    result = try await session.data(for: request)
                }
            }
            return result
        } catch is CancellationError {
            throw APIError.cancelled
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func perform(_ request: URLRequest, authenticated: Bool) async throws -> (Data, URLResponse) {
        var request = request
        if authenticated {
            guard let token = try keychain.current()?.tokens.accessToken, !token.isEmpty else { throw APIError.unauthorized }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            var result = try await session.data(for: request)
            if let http = result.1 as? HTTPURLResponse, http.statusCode == 401 && authenticated {
                _ = try await refreshSession()
                if let token = try keychain.current()?.tokens.accessToken {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    result = try await session.data(for: request)
                }
            }
            return result
        } catch is CancellationError {
            throw APIError.cancelled
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func decodeError(_ data: Data, status: Int) -> APIError {
        guard !data.isEmpty else { return .server(status: status, code: nil, message: nil) }
        do {
            let payload = try decoder.decode(APIErrorResponse.self, from: data)
            return .server(status: status, code: payload.error.code, message: payload.error.message)
        } catch {
            return .server(status: status, code: nil, message: String(localized: "error_request_failed"))
        }
    }
}

private struct AnyEncodable: Encodable {
    private let value: any Encodable

    init(_ value: any Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

private actor RefreshCoordinator {
    private var active: Task<StoredSession, Error>?

    func run(_ work: @escaping () async throws -> StoredSession) async throws -> StoredSession {
        if let active {
            return try await active.value
        }
        let task = Task { try await work() }
        self.active = task
        do {
            let session = try await task.value
            active = nil
            return session
        } catch {
            active = nil
            throw error
        }
    }
}
