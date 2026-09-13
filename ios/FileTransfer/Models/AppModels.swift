import Foundation
#if canImport(UIKit)
import SwiftUI
#endif

enum APIJSON {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                "yyyy-MM-dd HH:mm:ss"
            ]
            for format in formats {
                let formatter = DateFormatter()
                formatter.calendar = Calendar(identifier: .iso8601)
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = format
                if let date = formatter.date(from: value) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date: \(value)")
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

struct ServerEndpoints: Codable, Equatable, Sendable {
    let origin: String
    let apiBase: String
    let health: URL
    let auth: URL
    let users: URL
    let friends: URL
    let chat: URL
    let transfers: URL
    let releases: URL
    let websocket: URL
}

enum TransferStatus: String, Codable, CaseIterable, Sendable {
    case uploading
    case downloading
    case complete
    case failed
    case cancelled

    var isTerminal: Bool {
        self == .complete || self == .failed || self == .cancelled
    }

    var title: String {
        switch self {
        case .uploading: return String(localized: "transfer_uploading")
        case .downloading: return String(localized: "transfer_downloading")
        case .complete: return String(localized: "transfer_complete")
        case .failed: return String(localized: "transfer_failed")
        case .cancelled: return String(localized: "transfer_cancelled")
        }
    }
}

struct User: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let numericId: Int
    let username: String
    let email: String
    let displayName: String
    let createdAt: Date
    let lastSeenAt: Date?
}

struct AuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accessExpiresAt: Date
    let refreshExpiresAt: Date
    let sessionId: String
}

struct AuthResponse: Codable, Sendable {
    let user: User
    let tokens: AuthTokens
}

struct RefreshResponse: Codable, Sendable {
    let tokens: AuthTokens
}

struct StoredSession: Codable, Equatable, Sendable {
    let tokens: AuthTokens
    let user: User?
}

struct RegisterRequest: Encodable, Sendable {
    let username: String?
    let email: String?
    let displayName: String?
    let password: String
}

struct LoginRequest: Encodable, Sendable {
    let username: String?
    let email: String?
    let password: String
}

struct RefreshRequest: Encodable, Sendable {
    let refreshToken: String
}

enum Relationship: String, Codable, Sendable {
    case none
    case pending
    case accepted
    case blocked
}

struct SearchUser: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let numericId: Int
    let username: String
    let email: String
    let displayName: String
    let createdAt: Date
    let lastSeenAt: Date?
    let relationship: Relationship
}

struct Friend: Codable, Identifiable, Hashable, Equatable, Sendable {
    let id: String
    let numericId: Int
    let username: String
    let email: String
    let displayName: String
    let createdAt: Date
    let lastSeenAt: Date?
    let status: String
    var online: Bool

    init(
        id: String,
        numericId: Int,
        username: String,
        email: String,
        displayName: String,
        createdAt: Date,
        lastSeenAt: Date?,
        status: String,
        online: Bool
    ) {
        self.id = id
        self.numericId = numericId
        self.username = username
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
        self.status = status
        self.online = online
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        numericId = try container.decode(Int.self, forKey: .numericId)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        displayName = try container.decode(String.self, forKey: .displayName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt)
        status = try container.decode(String.self, forKey: .status)
        online = try container.decodeIfPresent(Bool.self, forKey: .online) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(numericId, forKey: .numericId)
        try container.encode(username, forKey: .username)
        try container.encode(email, forKey: .email)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastSeenAt, forKey: .lastSeenAt)
        try container.encode(status, forKey: .status)
        try container.encode(online, forKey: .online)
    }

    enum CodingKeys: String, CodingKey {
        case id, numericId, username, email, displayName, createdAt, lastSeenAt, status, online
    }
}

struct PresenceRecord: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let numericId: Int
    let username: String
    let email: String
    let displayName: String
    let createdAt: Date
    let lastSeenAt: Date?
    let status: String
    let online: Bool

    var friend: Friend {
        Friend(
            id: id,
            numericId: numericId,
            username: username,
            email: email,
            displayName: displayName,
            createdAt: createdAt,
            lastSeenAt: lastSeenAt,
            status: status,
            online: online
        )
    }
}

enum FriendRequestDirection: String, Codable, Sendable {
    case incoming
    case outgoing
}

struct FriendRequestRecord: Codable, Identifiable, Equatable, Sendable {
    let requesterId: Int
    let requesterUsername: String
    let addresseeId: Int
    let addresseeUsername: String
    let createdAt: Date
    let direction: FriendRequestDirection

    var id: Int { direction == .incoming ? requesterId : addresseeId }
    var displayName: String { direction == .incoming ? requesterUsername : addresseeUsername }
}

struct ChatMessage: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let senderId: String
    let recipientId: String
    let senderNumericId: Int
    let recipientNumericId: Int
    let body: String
    let clientMessageId: String?
    let createdAt: Date
    let readAt: Date?

    enum DeliveryState: String, Codable, Sendable {
        case sending
        case sent
        case delivered
        case read
        case failed
    }

    func isOutgoing(for userID: Int) -> Bool { senderNumericId == userID }
}

struct SendMessageRequest: Encodable, Sendable {
    let recipientId: Int
    let content: String
    let clientMessageId: String?
}

struct Transfer: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let senderId: String
    let recipientId: String
    let senderNumericId: Int
    let recipientNumericId: Int
    let filename: String
    let size: Int64
    let sha256: String
    let chunkSize: Int64
    let status: TransferStatus
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?

    func peerNumericId(for userID: Int) -> Int {
        senderNumericId == userID ? recipientNumericId : senderNumericId
    }

    func isOutgoing(for userID: Int) -> Bool { senderNumericId == userID }
}

struct TransferChunk: Codable, Identifiable, Equatable, Sendable {
    let transferId: String
    let chunkIndex: Int
    let size: Int64
    let sha256: String
    let createdAt: Date

    var id: String { "\(transferId):\(chunkIndex)" }
}

struct UploadCreationRequest: Encodable, Sendable {
    let recipientId: Int
    let filename: String
    let size: Int64
    let sha256: String
    let chunkSize: Int64
}

struct UploadStatusResponse: Codable, Sendable {
    let chunks: [TransferChunk]
}

struct HealthStatus: Codable, Equatable, Sendable {
    let status: String
    let version: String
    let database: String
    let storage: String
    let websocket: String
    let checkedAt: Date
}

#if !canImport(UIKit)
extension String {
    init(localized key: String) {
        self = key
    }
}
#endif

struct APIErrorResponse: Codable, Sendable {
    let error: APIErrorDetails
}

struct APIErrorDetails: Codable, Sendable {
    let code: String
    let message: String
    let details: [String: CodableValue]?
}

struct CodableValue: Codable, Sendable {
    let value: JSONValue

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = .bool(bool)
        } else if let string = try? container.decode(String.self) {
            value = .string(string)
        } else if let number = try? container.decode(Double.self) {
            value = .number(number)
        } else if let array = try? container.decode([CodableValue].self) {
            value = .array(array.map(\.value))
        } else if let object = try? container.decode([String: CodableValue].self) {
            value = .object(object.mapValues(\.value))
        } else {
            value = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }

    enum JSONValue: Codable, Sendable {
        case bool(Bool)
        case string(String)
        case number(Double)
        case array([JSONValue])
        case object([String: JSONValue])
        case null
    }
}

struct LocalFileItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    let filename: String
    let byteCount: Int64
    let contentType: String
    let importedAt: Date

    init(id: String, url: URL, filename: String, byteCount: Int64, contentType: String, importedAt: Date) {
        self.id = id
        self.url = url
        self.filename = filename
        self.byteCount = byteCount
        self.contentType = contentType
        self.importedAt = importedAt
    }
}

struct TransferProgress: Equatable, Sendable {
    let transferId: String
    let completedChunks: Int
    let totalChunks: Int
    let bytesTransferred: Int64
    let totalBytes: Int64
    let state: TransferStatus

    var fraction: Double {
        guard totalBytes > 0 else { return totalChunks == 0 ? 1 : 0 }
        return min(1, max(0, Double(bytesTransferred) / Double(totalBytes)))
    }

    var percent: Int { Int((fraction * 100).rounded()) }
}

struct TransferJob: Identifiable, Equatable, Sendable {
    let transfer: Transfer
    let sourceURL: URL?
    let destinationURL: URL?
    let progress: TransferProgress?
    let error: String?

    var id: String { transfer.id }
}

enum JSONValue: Codable, Sendable {
    case bool(Bool)
    case string(String)
    case number(Double)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .bool(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    func decoded<T: Decodable>(as type: T.Type) -> T? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return try? APIJSON.decoder().decode(type, from: data)
    }
}

struct WebSocketEvent: Decodable, Sendable {
    let type: String
    let data: JSONValue?
    let error: APIErrorDetails?
}

struct PresenceEvent: Decodable, Sendable {
    let userId: Int
    let online: Bool
}

struct FriendListResponse: Decodable, Sendable {
    let users: [Friend]
}

struct PresenceListResponse: Decodable, Sendable {
    let users: [PresenceRecord]
}

struct FriendRequestResponse: Decodable, Sendable {
    let request: FriendRequestRecord
}

struct FriendRequestListResponse: Decodable, Sendable {
    let requests: [FriendRequestRecord]
}

struct SearchUsersResponse: Decodable, Sendable {
    let users: [SearchUser]
}

struct UserResponse: Decodable, Sendable {
    let user: User
}

struct MessageResponse: Decodable, Sendable {
    let message: ChatMessage
}

struct ReadResponse: Decodable, Sendable {
    let read: Int?
    let count: Int?

    var value: Int { read ?? count ?? 0 }
}

struct MessageListResponse: Decodable, Sendable {
    let messages: [ChatMessage]
}

struct TransferListResponse: Decodable, Sendable {
    let transfers: [Transfer]
}

struct TransferResponse: Decodable, Sendable {
    let transfer: Transfer
}

struct TransferChunksResponse: Decodable, Sendable {
    let chunks: [TransferChunk]
}

struct UploadChunkResponse: Decodable, Sendable {
    let chunk: TransferChunk
    let complete: Bool
    let transfer: Transfer
}

struct DownloadChunkResponse: Sendable {
    let data: Data
    let contentRange: String?
    let etag: String?
}

enum AppTheme: String, Codable, CaseIterable, Hashable, Sendable {
    case system
    case light
    case dark
}

#if canImport(UIKit)
extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
#endif

enum AppLanguage: String, Codable, CaseIterable, Hashable, Sendable {
    case system
    case english = "en"
    case vietnamese = "vi"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    var displayName: String {
        switch self {
        case .system: return String(localized: "language_system")
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        case .simplifiedChinese: return "中文（简体）"
        case .traditionalChinese: return "中文（繁體）"
        case .japanese: return "日本語"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .system: return Locale.preferredLanguages.first ?? "en"
        default: return rawValue
        }
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    var serverURL: String
    var language: AppLanguage
    var theme: AppTheme

    static let `default` = AppSettings(serverURL: "", language: .system, theme: .system)
}
