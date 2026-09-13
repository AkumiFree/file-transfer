import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

#if canImport(Combine)
typealias LocalFileStoreBase = ObservableObject
#else
protocol LocalFileStoreBase {}
#endif

final class LocalFileStore: LocalFileStoreBase {
#if canImport(Combine)
    @Published private(set) var items: [LocalFileItem] = []
#else
    private(set) var items: [LocalFileItem] = []
#endif
    private let fileManager: FileManager
    private let metadataURL: URL
    private let directoryURL: URL

    init(fileManager: FileManager = .default, directoryURL: URL? = nil, metadataURL: URL? = nil) {
        self.fileManager = fileManager
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.directoryURL = directoryURL ?? support.appendingPathComponent("FileTransfer/Files", isDirectory: true)
        self.metadataURL = metadataURL ?? self.directoryURL.appendingPathComponent("files.json")
        try? fileManager.createDirectory(at: self.directoryURL, withIntermediateDirectories: true)
        load()
    }

    func importFiles(from urls: [URL]) throws -> [LocalFileItem] {
        var imported: [LocalFileItem] = []
        for source in urls {
#if canImport(UIKit)
            let accessing = source.startAccessingSecurityScopedResource()
            defer { if accessing { source.stopAccessingSecurityScopedResource() } }
#endif
            let attributes = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard attributes.isRegularFile == true else { continue }
            let size = Int64(attributes.fileSize ?? 0)
            let extensionName = source.pathExtension.isEmpty ? "bin" : source.pathExtension
            let destination = directoryURL.appendingPathComponent("\(UUID().uuidString).\(extensionName)")
            do {
                try copy(source, to: destination)
            } catch {
                try? fileManager.removeItem(at: destination)
                throw error
            }
#if canImport(UniformTypeIdentifiers)
            let contentType = try source.resourceValues(forKeys: [.contentTypeKey]).contentType?.preferredMIMEType
                ?? UTType(filenameExtension: extensionName)?.preferredMIMEType
                ?? "application/octet-stream"
#else
            let contentType = Self.mimeType(for: extensionName)
#endif
            let item = LocalFileItem(id: UUID().uuidString, url: destination, filename: source.lastPathComponent, byteCount: size, contentType: contentType, importedAt: Date())
            imported.append(item)
        }
        if !imported.isEmpty {
            items.append(contentsOf: imported)
            try save()
        }
        return imported
    }

    func delete(_ item: LocalFileItem) throws {
        try fileManager.removeItem(at: item.url)
        items.removeAll { $0.id == item.id }
        try save()
    }

    func item(id: String) -> LocalFileItem? {
        items.first { $0.id == id }
    }

    func url(for item: LocalFileItem) -> URL { item.url }

    private static func mimeType(for extensionName: String) -> String {
        switch extensionName.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }

    private func copy(_ source: URL, to destination: URL) throws {
        if !fileManager.fileExists(atPath: destination.path) {
            guard fileManager.createFile(atPath: destination.path, contents: nil) else { throw APIError.decoding(String(localized: "error_file_create")) }
        }
        let input = try FileHandle(forReadingFrom: source)
        let output = try FileHandle(forWritingTo: destination)
        defer {
            try? input.close()
            try? output.close()
        }
        while let data = try input.read(upToCount: 1024 * 1024), !data.isEmpty {
            try output.write(contentsOf: data)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: metadataURL), let decoded = try? JSONDecoder().decode([LocalFileItem].self, from: data) else {
            items = []
            return
        }
        items = decoded.filter { fileManager.fileExists(atPath: $0.url.path) }
    }

    private func save() throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: metadataURL, options: .atomic)
    }
}
