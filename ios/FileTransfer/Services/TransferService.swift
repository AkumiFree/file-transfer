#if canImport(CryptoKit)
import CryptoKit
#endif
import Foundation
#if canImport(Combine)
import Combine
#endif

protocol TransferAPI {
    func createTransfer(recipientID: Int, filename: String, size: Int64, sha256: String, chunkSize: Int64) async throws -> Transfer
    func transferChunks(id: String) async throws -> [TransferChunk]
    func uploadChunk(transferID: String, index: Int, data: Data, totalSize: Int64, chunkSize: Int64, sha256: String) async throws -> Transfer
    func downloadChunk(transferID: String, start: Int64, end: Int64) async throws -> DownloadChunkResponse
    func completeTransfer(id: String) async throws -> Transfer
    func cancelTransfer(id: String) async throws
}

extension APIClient: TransferAPI {}

#if canImport(Combine)
typealias TransferServiceBase = ObservableObject
#else
protocol TransferServiceBase {}
#endif

#if !canImport(CryptoKit)
private struct SHA256Fallback {
    private let constants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]
    private var state: [UInt32] = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
    private var buffer = Data()
    private var bitLength: UInt64 = 0

    mutating func update(data: Data) {
        bitLength += UInt64(data.count) * 8
        buffer.append(data)
        while buffer.count >= 64 {
            process(Array(buffer.prefix(64)))
            buffer.removeFirst(64)
        }
    }

    mutating func finalize() -> [UInt8] {
        var message = buffer
        let length = bitLength
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        var lengthBytes = length.bigEndian
        withUnsafeBytes(of: &lengthBytes) { message.append(contentsOf: $0) }
        process(Array(message))
        return state.flatMap { word in
            [UInt8(truncatingIfNeeded: word >> 24), UInt8(truncatingIfNeeded: word >> 16), UInt8(truncatingIfNeeded: word >> 8), UInt8(truncatingIfNeeded: word)]
        }
    }

    private mutating func process(_ block: [UInt8]) {
        var words = [UInt32](repeating: 0, count: 64)
        for index in 0..<16 {
            let offset = index * 4
            words[index] = UInt32(block[offset]) << 24 | UInt32(block[offset + 1]) << 16 | UInt32(block[offset + 2]) << 8 | UInt32(block[offset + 3])
        }
        for index in 16..<64 {
            let a = words[index - 15]
            let b = words[index - 2]
            let smallA = rotateRight(a, 7) ^ rotateRight(a, 18) ^ (a >> 3)
            let smallB = rotateRight(b, 17) ^ rotateRight(b, 19) ^ (b >> 10)
            words[index] = words[index - 16] &+ smallA &+ words[index - 7] &+ smallB
        }
        var a = state[0], b = state[1], c = state[2], d = state[3]
        var e = state[4], f = state[5], g = state[6], h = state[7]
        for index in 0..<64 {
            let sum1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25)
            let choose = (e & f) ^ ((~e) & g)
            let temp1 = h &+ sum1 &+ choose &+ constants[index] &+ words[index]
            let sum0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22)
            let majority = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = sum0 &+ majority
            h = g; g = f; f = e; e = d &+ temp1
            d = c; c = b; b = a; a = temp1 &+ temp2
        }
        state[0] &+= a; state[1] &+= b; state[2] &+= c; state[3] &+= d
        state[4] &+= e; state[5] &+= f; state[6] &+= g; state[7] &+= h
    }

    private func rotateRight(_ value: UInt32, _ count: UInt32) -> UInt32 {
        (value >> count) | (value << (32 - count))
    }
}
#endif

final class TransferService: TransferServiceBase {
#if canImport(Combine)
    @Published private(set) var progressByTransfer: [String: TransferProgress] = [:]
#else
    private(set) var progressByTransfer: [String: TransferProgress] = [:]
#endif
    static let chunkSize: Int64 = 8 * 1024 * 1024
    private let api: any TransferAPI
    private let fileManager: FileManager

    init(api: any TransferAPI, fileManager: FileManager = .default) {
        self.api = api
        self.fileManager = fileManager
    }

    func upload(file: LocalFileItem, recipient: Friend) async throws -> Transfer {
        let attributes = try file.url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = attributes.fileSize else { throw APIError.decoding(String(localized: "error_file_size")) }
        let size = Int64(fileSize)
        let hash = try Self.sha256(of: file.url)
        let transfer = try await api.createTransfer(
            recipientID: recipient.numericId,
            filename: file.filename,
            size: size,
            sha256: hash,
            chunkSize: Self.chunkSize
        )
        let ranges = Self.chunkRanges(size: size, chunkSize: transfer.chunkSize)
        var received = Set(try await api.transferChunks(id: transfer.id).map(\.chunkIndex))
        var bytesTransferred = received.reduce(Int64(0)) { total, index in
            guard let range = ranges.first(where: { $0.index == index }) else { return total }
            return total + range.size
        }
        publish(TransferProgress(transferId: transfer.id, completedChunks: received.count, totalChunks: ranges.count, bytesTransferred: bytesTransferred, totalBytes: size, state: .uploading))

        for range in ranges {
            try Task.checkCancellation()
            if received.contains(range.index) { continue }
            let data = try Self.read(file.url, offset: range.start, length: range.size)
            let chunkHash = Self.sha256(data)
            let updated = try await api.uploadChunk(
                transferID: transfer.id,
                index: range.index,
                data: data,
                totalSize: size,
                chunkSize: transfer.chunkSize,
                sha256: chunkHash
            )
            received.insert(range.index)
            bytesTransferred += range.size
            publish(TransferProgress(transferId: transfer.id, completedChunks: received.count, totalChunks: ranges.count, bytesTransferred: bytesTransferred, totalBytes: size, state: updated.status))
        }

        let completed = try await api.completeTransfer(id: transfer.id)
        publish(TransferProgress(transferId: completed.id, completedChunks: ranges.count, totalChunks: ranges.count, bytesTransferred: size, totalBytes: size, state: completed.status))
        return completed
    }

    func restoreProgress(for transfer: Transfer) async throws {
        let ranges = Self.chunkRanges(size: transfer.size, chunkSize: transfer.chunkSize)
        let received = Set(try await api.transferChunks(id: transfer.id).map(\.chunkIndex))
        let bytesTransferred = received.reduce(Int64(0)) { total, index in
            guard let range = ranges.first(where: { $0.index == index }) else { return total }
            return total + range.size
        }
        publish(TransferProgress(
            transferId: transfer.id,
            completedChunks: received.count,
            totalChunks: ranges.count,
            bytesTransferred: bytesTransferred,
            totalBytes: transfer.size,
            state: transfer.status
        ))
    }

    func download(transfer: Transfer, destinationURL: URL) async throws {
        let ranges = Self.chunkRanges(size: transfer.size, chunkSize: transfer.chunkSize)
        let chunks = try await api.transferChunks(id: transfer.id)
        let chunkByIndex = Dictionary(uniqueKeysWithValues: chunks.map { ($0.chunkIndex, $0) })
        if !fileManager.fileExists(atPath: destinationURL.path) {
            guard fileManager.createFile(atPath: destinationURL.path, contents: nil) else { throw APIError.decoding(String(localized: "error_file_create")) }
        }
        var bytesTransferred = Int64(0)
        do {
            let handle = try FileHandle(forWritingTo: destinationURL)
            defer { try? handle.close() }
            for range in ranges {
                try Task.checkCancellation()
                let expectedHash = chunkByIndex[range.index]?.sha256
                if let existing = try? Self.read(destinationURL, offset: range.start, length: range.size),
                   existing.count == Int(range.size),
                   let expectedHash,
                   Self.sha256(existing) == expectedHash {
                    bytesTransferred += range.size
                    publish(TransferProgress(transferId: transfer.id, completedChunks: completedCount(bytesTransferred: bytesTransferred, ranges: ranges), totalChunks: ranges.count, bytesTransferred: bytesTransferred, totalBytes: transfer.size, state: .downloading))
                    continue
                }
                let response = try await api.downloadChunk(transferID: transfer.id, start: range.start, end: range.end)
                guard response.data.count == Int(range.size) else { throw APIError.decoding(String(localized: "error_chunk_length")) }
                let actualHash = Self.sha256(response.data)
                if let expectedHash, actualHash != expectedHash { throw APIError.decoding(String(localized: "error_chunk_checksum")) }
                try handle.seek(toOffset: UInt64(range.start))
                try handle.write(contentsOf: response.data)
                bytesTransferred += Int64(response.data.count)
                publish(TransferProgress(transferId: transfer.id, completedChunks: completedCount(bytesTransferred: bytesTransferred, ranges: ranges), totalChunks: ranges.count, bytesTransferred: bytesTransferred, totalBytes: transfer.size, state: .downloading))
            }
            try handle.truncate(atOffset: UInt64(transfer.size))
        }
        let finalHash = try Self.sha256(of: destinationURL)
        guard finalHash == transfer.sha256 else { throw APIError.decoding(String(localized: "error_file_checksum")) }
        publish(TransferProgress(transferId: transfer.id, completedChunks: ranges.count, totalChunks: ranges.count, bytesTransferred: transfer.size, totalBytes: transfer.size, state: .complete))
    }

    func cancel(transferID: String) async throws {
        try await api.cancelTransfer(id: transferID)
        progressByTransfer[transferID] = nil
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
#if canImport(CryptoKit)
        var hash = SHA256()
        try handle.seek(toOffset: 0)
        while let data = try handle.read(upToCount: Int(chunkSize)), !data.isEmpty {
            hash.update(data: data)
        }
        return hex(hash.finalize())
#else
        var hash = SHA256Fallback()
        try handle.seek(toOffset: 0)
        while let data = try handle.read(upToCount: Int(chunkSize)), !data.isEmpty {
            hash.update(data: data)
        }
        return hex(hash.finalize())
#endif
    }

    static func sha256(_ data: Data) -> String {
#if canImport(CryptoKit)
        var hash = SHA256()
        hash.update(data: data)
        return hex(hash.finalize())
#else
        var hash = SHA256Fallback()
        hash.update(data: data)
        return hex(hash.finalize())
#endif
    }

    static func chunkRanges(size: Int64, chunkSize: Int64) -> [(index: Int, start: Int64, end: Int64, size: Int64)] {
        guard size > 0, chunkSize > 0 else { return [] }
        var ranges: [(index: Int, start: Int64, end: Int64, size: Int64)] = []
        var start: Int64 = 0
        while start < size {
            let end = min(start + chunkSize - 1, size - 1)
            ranges.append((ranges.count, start, end, end - start + 1))
            start += chunkSize
        }
        return ranges
    }

    private static func read(_ url: URL, offset: Int64, length: Int64) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        return try handle.read(upToCount: Int(length)) ?? Data()
    }

#if canImport(CryptoKit)
    private static func hex(_ digest: Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
#else
    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
#endif

    private func completedCount(bytesTransferred: Int64, ranges: [(index: Int, start: Int64, end: Int64, size: Int64)]) -> Int {
        ranges.prefix(while: { range in
            let endOffset = range.end + 1
            return bytesTransferred >= endOffset
        }).count
    }

    private func publish(_ progress: TransferProgress) {
        progressByTransfer[progress.transferId] = progress
    }
}
