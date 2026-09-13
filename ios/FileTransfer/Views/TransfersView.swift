import SwiftUI

struct TransfersView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedFriendID: Int?
    @State private var selectedFileID: String?
    @State private var downloadName: String?

    var body: some View {
        List {
            Section {
                Picker(String(localized: "friend"), selection: $selectedFriendID) {
                    Text(String(localized: "choose")).tag(Optional<Int>(nil))
                    ForEach(appState.friends) { friend in
                        Text(friend.displayName).tag(Optional(friend.numericId))
                    }
                }
                Picker(String(localized: "file"), selection: $selectedFileID) {
                    Text(String(localized: "choose")).tag(Optional<String>(nil))
                    ForEach(appState.localFiles.items) { item in
                        Text(item.filename).tag(Optional(item.id))
                    }
                }
                Button(action: upload) {
                    Label(String(localized: "upload"), systemImage: "arrow.up.doc")
                }
                .frame(maxWidth: .infinity)
                .disabled(selectedFriendID == nil || selectedFileID == nil || appState.isBusy)
            } header: {
                Text(String(localized: "send_file"))
            } footer: {
                Text(String(localized: "upload_help"))
            }

            Section {
                if appState.transfers.isEmpty {
                    EmptyState(systemImage: "arrow.up.arrow.down", title: String(localized: "no_transfers"), subtitle: String(localized: "no_transfers_hint"))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(appState.transfers) { transfer in
                        TransferRow(
                            transfer: transfer,
                            progress: appState.transferService?.progressByTransfer[transfer.id],
                            isDownloading: !transfer.isOutgoing(for: appState.user?.numericId ?? -1) && !transfer.status.isTerminal
                        )
                        .contextMenu {
                            if transfer.status == .complete && !transfer.isOutgoing(for: appState.user?.numericId ?? -1) {
                                Button(String(localized: "download")) { download(transfer) }
                            }
                            if transfer.status == .uploading {
                                Button(String(localized: "cancel"), role: .destructive) { Task { await appState.cancel(transfer) } }
                            }
                        }
                    }
                }
            } header: {
                Text(String(localized: "transfers"))
            }
        }
        .navigationTitle(String(localized: "transfers"))
        .task {
            await appState.loadFriends()
            await appState.loadTransfers()
        }
        .alert(String(localized: "download_complete"), isPresented: downloadBinding()) {
            Button(String(localized: "ok"), role: .cancel) { downloadName = nil }
        } message: {
            Text(downloadName ?? "")
        }
        .alert(String(localized: "error"), isPresented: errorBinding()) {
            Button(String(localized: "ok"), role: .cancel) { appState.clearError() }
        } message: {
            Text(appState.lastError ?? "")
        }
    }

    private func upload() {
        guard let friend = appState.friends.first(where: { $0.numericId == selectedFriendID }),
              let item = appState.localFiles.items.first(where: { $0.id == selectedFileID }) else { return }
        Task { await appState.upload(item, to: friend) }
    }

    private func download(_ transfer: Transfer) {
        Task {
            if let url = await appState.download(transfer) {
                downloadName = url.lastPathComponent
            }
        }
    }

    private func downloadBinding() -> Binding<Bool> {
        Binding(get: { downloadName != nil }, set: { if !$0 { downloadName = nil } })
    }

    private func errorBinding() -> Binding<Bool> {
        Binding(get: { appState.lastError != nil }, set: { if !$0 { appState.clearError() } })
    }
}

private struct TransferRow: View {
    let transfer: Transfer
    let progress: TransferProgress?
    let isDownloading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FileIcon(filename: transfer.filename)
                VStack(alignment: .leading, spacing: 3) {
                    Text(transfer.filename).font(.body.weight(.semibold)).lineLimit(1)
                    Text(ByteCountFormatter.string(fromByteCount: transfer.size, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(text: transfer.status.title, online: transfer.status == .complete)
            }
            ProgressRow(
                progress: progress ?? TransferProgress(transferId: transfer.id, completedChunks: transfer.status == .complete ? 1 : 0, totalChunks: 1, bytesTransferred: transfer.status == .complete ? transfer.size : 0, totalBytes: transfer.size, state: transfer.status),
                isDownloading: isDownloading
            )
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
