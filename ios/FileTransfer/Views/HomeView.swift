import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                healthCard
                summaryGrid
                offlineCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(localized: "home"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { Task { await appState.testConnection() } }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await appState.testConnection() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "welcome"))
                .font(.title2.weight(.bold))
            Text(appState.user?.displayName ?? appState.user?.username ?? "")
                .foregroundStyle(.secondary)
            if let health = appState.health {
                StatusPill(text: health.status == "ok" ? String(localized: "connected") : String(localized: "degraded"), online: health.status == "ok")
            } else {
                StatusPill(text: String(localized: "disconnected"), online: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "connection"))
                .font(.headline)
            if let health = appState.health {
                LabeledContent(String(localized: "server_version"), value: health.version)
                LabeledContent(String(localized: "database"), value: health.database)
                LabeledContent(String(localized: "storage"), value: health.storage)
                LabeledContent(String(localized: "websocket"), value: health.websocket)
            } else {
                Text(String(localized: "connection_not_checked"))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            SummaryTile(image: "person.2", value: "\(appState.friends.count)", label: String(localized: "friends"))
            SummaryTile(image: "message", value: "\(appState.conversations.values.flatMap { $0 }.count)", label: String(localized: "messages"))
            SummaryTile(image: "arrow.up.arrow.down", value: "\(appState.transfers.count)", label: String(localized: "transfers"))
        }
    }

    private var offlineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "offline_title"), systemImage: "externaldrive")
                .font(.headline)
            Text(String(localized: "offline_body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(localized: "offline_tip"))
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct SummaryTile: View {
    let image: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: image)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
