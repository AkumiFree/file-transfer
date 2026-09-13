#if canImport(CryptoKit)
import CryptoKit
#endif
import Foundation
import XCTest
@testable import FileTransferCore

final class ModelDecodingTests: XCTestCase {
    func testAuthResponseMatchesBackendShape() throws {
        let json = """
        {
          "user": {
            "id": "7", "numericId": 7, "username": "alice", "email": "alice@example.test",
            "displayName": "Alice", "createdAt": "2026-09-11T09:00:00.000Z", "lastSeenAt": null
          },
          "tokens": {
            "accessToken": "access", "refreshToken": "refresh",
            "accessExpiresAt": "2026-09-11T10:00:00Z",
            "refreshExpiresAt": "2026-09-12T10:00:00Z", "sessionId": "session-1"
          }
        }
        """.data(using: .utf8)!

        let response = try APIJSON.decoder().decode(AuthResponse.self, from: json)
        XCTAssertEqual(response.user.numericId, 7)
        XCTAssertEqual(response.tokens.sessionId, "session-1")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour], from: response.user.createdAt)
        XCTAssertEqual(dateComponents.year, 2026)
        XCTAssertEqual(dateComponents.month, 9)
        XCTAssertEqual(dateComponents.day, 11)
        XCTAssertEqual(dateComponents.hour, 9)
    }

    func testTransferAndChunkResponsesMatchBackendShape() throws {
        let json = """
        {
          "transfer": {
            "id": "transfer-1", "senderId": "1", "recipientId": "2",
            "senderNumericId": 1, "recipientNumericId": 2, "filename": "note.txt",
            "size": 8, "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "chunkSize": 4, "status": "uploading",
            "createdAt": "2026-09-11T09:00:00Z", "updatedAt": "2026-09-11T09:00:01Z",
            "completedAt": null
          }
        }
        """.data(using: .utf8)!
        let response = try APIJSON.decoder().decode(TransferResponse.self, from: json)
        XCTAssertEqual(response.transfer.filename, "note.txt")
        XCTAssertEqual(response.transfer.status, .uploading)
        XCTAssertNil(response.transfer.completedAt)
    }

    func testWebSocketEventDecodesBackendEnvelope() throws {
        let json = """
        {"type":"chat.message","data":{"id":"9","senderId":"1","recipientId":"2","senderNumericId":1,"recipientNumericId":2,"body":"hello","clientMessageId":null,"createdAt":"2026-09-11T09:00:00Z","readAt":null}}
        """.data(using: .utf8)!
        let event = try APIJSON.decoder().decode(WebSocketEvent.self, from: json)
        XCTAssertEqual(event.type, "chat.message")
        let message = try XCTUnwrap(event.data?.decoded(as: ChatMessage.self))
        XCTAssertEqual(message.body, "hello")
    }

    func testSettingsRoundTrip() throws {
        let settings = AppSettings(serverURL: "https://example.test", language: .japanese, theme: .dark)
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: data), settings)
    }
}

final class EndpointResolverTests: XCTestCase {
    func testResolvesAPIAndWebSocketOrigins() throws {
        let endpoints = try EndpointResolver.resolve(input: "https://files.example.test:8443/local/")
        XCTAssertEqual(endpoints.apiBase, "https://files.example.test:8443/local/api/v1")
        XCTAssertEqual(endpoints.health.path, "/local/api/v1/health")
        XCTAssertEqual(endpoints.websocket.scheme, "wss")
        XCTAssertEqual(endpoints.websocket.host, "files.example.test")
        XCTAssertEqual(endpoints.websocket.port, 8443)
        XCTAssertEqual(endpoints.websocket.path, "/local/ws")
    }

    func testRejectsEmbeddedCredentials() {
        XCTAssertThrowsError(try EndpointResolver.resolve(input: "https://user:pass@example.test"))
    }
}

final class TransferServiceTests: XCTestCase {
    func testChunkRangesCoverFinalPartialChunk() {
        let ranges = TransferService.chunkRanges(size: 10, chunkSize: 4)
        XCTAssertEqual(ranges.map(\.index), [0, 1, 2])
        XCTAssertEqual(ranges.map(\.size), [4, 4, 2])
        XCTAssertTrue(TransferService.chunkRanges(size: 0, chunkSize: 4).isEmpty)
    }

    func testSHA256() {
        XCTAssertEqual(TransferService.sha256(Data("abc".utf8)), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testDownloadResumesOnlyMissingChunkAndVerifiesFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FileTransferTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let destination = directory.appendingPathComponent("download.bin")
        try Data("abcdXXXX".utf8).write(to: destination)
        let completeData = Data("abcdefgh".utf8)
        let transfer = Transfer(
            id: "transfer-1", senderId: "1", recipientId: "2", senderNumericId: 1, recipientNumericId: 2,
            filename: "download.bin", size: Int64(completeData.count),
            sha256: TransferService.sha256(completeData), chunkSize: 4, status: .complete,
            createdAt: Date(), updatedAt: Date(), completedAt: Date()
        )
        let chunk0 = TransferChunk(transferId: transfer.id, chunkIndex: 0, size: 4, sha256: TransferService.sha256(Data("abcd".utf8)), createdAt: Date())
        let chunk1 = TransferChunk(transferId: transfer.id, chunkIndex: 1, size: 4, sha256: TransferService.sha256(Data("efgh".utf8)), createdAt: Date())
        let api = MockTransferAPI(chunks: [chunk0, chunk1], missingChunkData: Data("efgh".utf8))
        let service = TransferService(api: api, fileManager: .default)

        try await service.download(transfer: transfer, destinationURL: destination)
        XCTAssertEqual(try Data(contentsOf: destination), completeData)
        XCTAssertEqual(api.downloadRanges.map(\.0), [4])
        XCTAssertEqual(api.downloadRanges.map(\.1), [7])
        XCTAssertEqual(service.progressByTransfer[transfer.id]?.state, .complete)
    }

    func testUploadSkipsAcceptedChunksAndCompletes() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FileTransferTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let sourceData = Data("abcdef".utf8)
        let source = directory.appendingPathComponent("source.bin")
        try sourceData.write(to: source)
        let item = LocalFileItem(id: "file-1", url: source, filename: "source.bin", byteCount: Int64(sourceData.count), contentType: "application/octet-stream", importedAt: Date())
        let friend = Friend(
            id: "2", numericId: 2, username: "bob", email: "bob@example.test", displayName: "Bob",
            createdAt: Date(), lastSeenAt: nil, status: "accepted", online: true
        )
        let transfer = Transfer(
            id: "transfer-1", senderId: "1", recipientId: "2", senderNumericId: 1, recipientNumericId: 2,
            filename: item.filename, size: Int64(sourceData.count), sha256: TransferService.sha256(sourceData),
            chunkSize: 4, status: .uploading, createdAt: Date(), updatedAt: Date(), completedAt: nil
        )
        let chunk0 = TransferChunk(transferId: transfer.id, chunkIndex: 0, size: 4, sha256: TransferService.sha256(Data("abcd".utf8)), createdAt: Date())
        let api = MockTransferAPI(chunks: [chunk0], createdTransfer: transfer, missingChunkData: Data("ef".utf8))
        let service = TransferService(api: api, fileManager: .default)

        let completed = try await service.upload(file: item, recipient: friend)
        XCTAssertEqual(completed.status, .complete)
        XCTAssertEqual(api.uploadedIndexes, [1])
        XCTAssertEqual(service.progressByTransfer[transfer.id]?.percent, 100)
    }
}

final class LocalFileStoreTests: XCTestCase {
    func testImportAndDeleteAreMetadataBacked() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("FileTransferStoreTests-\(UUID().uuidString)", isDirectory: true)
        let storeDirectory = root.appendingPathComponent("store", isDirectory: true)
        let metadata = storeDirectory.appendingPathComponent("files.json")
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.txt")
        try Data("local file".utf8).write(to: source)
        let store = LocalFileStore(directoryURL: storeDirectory, metadataURL: metadata)
        let imported = try store.importFiles(from: [source])
        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported[0].filename, "source.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported[0].url.path))
        XCTAssertEqual(store.items.count, 1)

        try store.delete(imported[0])
        XCTAssertFalse(FileManager.default.fileExists(atPath: imported[0].url.path))
        XCTAssertTrue(store.items.isEmpty)
    }
}

final class KeychainStoreTests: XCTestCase {
    func testMemorySessionStoreSupportsSaveReadAndDelete() throws {
        let store = KeychainStore(memoryOnly: true)
        let session = StoredSession(
            tokens: AuthTokens(accessToken: "a", refreshToken: "r", accessExpiresAt: Date(), refreshExpiresAt: Date(), sessionId: "s"),
            user: nil
        )
        try store.save(session)
        XCTAssertEqual(try store.current(), session)
        try store.delete()
        XCTAssertNil(try store.current())
    }
}

private final class MockTransferAPI: TransferAPI {
    let chunks: [TransferChunk]
    let createdTransfer: Transfer
    let missingChunkData: Data
    var downloadRanges: [(Int64, Int64)] = []
    var uploadedIndexes: [Int] = []

    init(
        chunks: [TransferChunk] = [],
        createdTransfer: Transfer? = nil,
        missingChunkData: Data = Data()
    ) {
        self.chunks = chunks
        self.createdTransfer = createdTransfer ?? Transfer(
            id: "transfer-1", senderId: "1", recipientId: "2", senderNumericId: 1, recipientNumericId: 2,
            filename: "file.bin", size: 0, sha256: TransferService.sha256(Data()), chunkSize: 4,
            status: .uploading, createdAt: Date(), updatedAt: Date(), completedAt: nil
        )
        self.missingChunkData = missingChunkData
    }

    func createTransfer(recipientID: Int, filename: String, size: Int64, sha256: String, chunkSize: Int64) async throws -> Transfer {
        createdTransfer
    }

    func transferChunks(id: String) async throws -> [TransferChunk] { chunks }

    func uploadChunk(transferID: String, index: Int, data: Data, totalSize: Int64, chunkSize: Int64, sha256: String) async throws -> Transfer {
        uploadedIndexes.append(index)
        return createdTransfer
    }

    func downloadChunk(transferID: String, start: Int64, end: Int64) async throws -> DownloadChunkResponse {
        downloadRanges.append((start, end))
        return DownloadChunkResponse(data: missingChunkData, contentRange: "bytes \(start)-\(end)/\(missingChunkData.count)", etag: nil)
    }

    func completeTransfer(id: String) async throws -> Transfer {
        var completed = createdTransfer
        completed = Transfer(
            id: completed.id, senderId: completed.senderId, recipientId: completed.recipientId,
            senderNumericId: completed.senderNumericId, recipientNumericId: completed.recipientNumericId,
            filename: completed.filename, size: completed.size, sha256: completed.sha256,
            chunkSize: completed.chunkSize, status: .complete, createdAt: completed.createdAt,
            updatedAt: Date(), completedAt: Date()
        )
        return completed
    }

    func cancelTransfer(id: String) async throws {}
}
