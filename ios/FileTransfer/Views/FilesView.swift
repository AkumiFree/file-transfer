import SwiftUI
import Foundation
import UniformTypeIdentifiers

struct FilesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportItem: LocalFileItem?
    @State private var deleteAfterExport = false
    @State private var importedMessage: String?

    var body: some View {
        List {
            Section {
                Button(action: { isImporting = true }) {
                    Label(String(localized: "import_files"), systemImage: "square.and.arrow.down.on.square")
                }
                .buttonStyle(.plain)
            } footer: {
                Text(String(localized: "import_files_help"))
            }

            Section {
                if appState.localFiles.items.isEmpty {
                    EmptyState(systemImage: "folder", title: String(localized: "no_local_files"), subtitle: String(localized: "no_local_files_hint"))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(appState.localFiles.items) { item in
                        FileRow(item: item)
                            .contextMenu {
                                Button(String(localized: "save_to_files")) { beginExport(item, delete: false) }
                                Button(String(localized: "save_and_delete")) { beginExport(item, delete: true) }
                                Divider()
                                Button(String(localized: "delete"), role: .destructive) { appState.deleteLocalFile(item) }
                            }
                    }
                }
            } header: {
                Text(String(localized: "local_files"))
            }

            Section {
                Text(String(localized: "offline_workflow_body"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } header: {
                Text(String(localized: "offline_workflow"))
            }
        }
        .navigationTitle(String(localized: "files"))
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case let .success(urls): appState.importFiles(urls)
            case let .failure(error): appState.setError(error.localizedDescription)
            }
        }
        .background {
            if let item = exportItem {
                EmptyView()
                    .fileExporter(
                        isPresented: $isExporting,
                        document: ExportableDocument(url: item.url),
                        contentType: .data,
                        defaultFilename: item.filename
                    ) { result in
                        switch result {
                        case .success:
                            importedMessage = String(localized: "export_complete")
                            let shouldDelete = deleteAfterExport
                            deleteAfterExport = false
                            if shouldDelete { appState.deleteLocalFile(item) }
                        case let .failure(error):
                            importedMessage = nil
                            appState.setError(error.localizedDescription)
                        }
                        exportItem = nil
                    }
            }
        }
        .overlay {
            if let importedMessage {
                Text(importedMessage)
                    .font(.footnote)
                    .padding(10)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding()
                    .transition(.opacity)
            }
        }
    }

    private func beginExport(_ item: LocalFileItem, delete: Bool) {
        exportItem = item
        deleteAfterExport = delete
        isExporting = true
    }
}

private struct FileRow: View {
    let item: LocalFileItem

    var body: some View {
        HStack(spacing: 12) {
            FileIcon(filename: item.filename)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.filename).font(.body.weight(.semibold)).lineLimit(1)
                HStack(spacing: 12) {
                    Text(ByteCountFormatter.string(fromByteCount: item.byteCount, countStyle: .file))
                    Text(item.contentType)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ExportableDocument: FileDocument {
    let url: URL

    static var readableContentTypes: [UTType] { [.data] }

    init(url: URL) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url, options: [])
    }
}
