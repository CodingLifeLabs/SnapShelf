import SwiftUI
import AppKit
import SnapShelfTypes

struct ShelfItemView: View {
    let item: ShelfItem
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(url: item.sourceURL)
                .frame(width: 96, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    if let app = item.appName {
                        Text(app)
                    }
                    Text(item.capturedAt, format: .dateTime.hour().minute())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if item.status == .pinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [item.displayName]
        if let app = item.appName { parts.append(app) }
        parts.append(item.capturedAt.formatted(date: .omitted, time: .shortened))
        return parts.joined(separator: ", ")
    }
}

/// Loads a thumbnail off the main thread to keep the shelf smooth.
struct ThumbnailView: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .task(id: url) {
            let loaded = await Task.detached(priority: .utility) { NSImage(contentsOf: url) }.value
            image = loaded
        }
    }
}
