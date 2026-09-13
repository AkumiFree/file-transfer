import SwiftUI
import CoreTransferable
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

            Section(String(localized: "local_files")) {
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
            }

            Section(String(localized: "offline_workflow")) {
                Text(String(localized: "offline_workflow_body"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(String(localized: "files"))
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case let .success(urls): appState.importFiles(urls)
            case let .failure(error): appState.lastError = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $isExporting, item: exportItem.map(ExportableFile.init), defaultFilename: exportItem?.filename ?? "file", contentTypes: [.data]) { result in
            switch result {
            case .success:
                importedMessage = String(localized: "export_complete")
                let shouldDelete = deleteAfterExport
                deleteAfterExport = false
                if shouldDelete, let item = exportItem { appState.deleteLocalFile(item) }
            case let .failure(error):
                importedMessage = nil
                appState.lastError = error.localizedDescription
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

private struct ExportableFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .data) { file in
            SentTransferredFile(file.url)
        }
    }
}
