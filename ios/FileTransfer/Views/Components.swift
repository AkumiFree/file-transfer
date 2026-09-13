import SwiftUI

struct ErrorBanner: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityRole(.alert)
        }
    }
}

struct EmptyState: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
    }
}

struct ProgressRow: View {
    let progress: TransferProgress?
    let isDownloading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text("\(progress?.percent ?? 0)%")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress?.fraction ?? 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var label: String {
        if isDownloading { return String(localized: "transfer_downloading") }
        return progress?.state.title ?? String(localized: "progress")
    }
}

struct StatusPill: View {
    let text: String
    let online: Bool

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((online ? Color.green : Color.gray).opacity(0.16))
            .foregroundStyle(online ? .green : .secondary)
            .clipShape(Capsule())
    }
}

struct FileIcon: View {
    let filename: String

    private var imageName: String {
        let ext = URL(fileURLWithPath: filename).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "jpg", "jpeg", "png", "heic": return "photo"
        case "mp3", "wav", "m4a": return "waveform"
        case "mp4", "mov": return "video"
        case "zip": return "archivebox"
        default: return "doc"
        }
    }

    var body: some View {
        Image(systemName: imageName)
            .font(.title3)
            .foregroundStyle(.accentColor)
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
    }
}
