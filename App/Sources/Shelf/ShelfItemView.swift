import SwiftUI
import AppKit
import SnapShelfTypes

struct ShelfItemView: View {
    let item: ShelfItem
    let reduceMotion: Bool
    var onPin: () -> Void
    var onStow: () -> Void
    var onCopyImage: () -> Void

    @State private var hovered = false
    @State private var copiedFlash = false
    @State private var isDragging = false

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
                    if let app = item.appName { Text(app) }
                    Text(item.capturedAt, format: .dateTime.hour().minute())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            hoverToolbar
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .overlay(accentRing)
        }
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator, lineWidth: 0.5))
        .contentShape(Rectangle())
        // Spec §4: lift on drag start (scale + elevation + accent ring), spring back on drop.
        .scaleEffect(isDragging ? 1.04 : 1.0)
        .shadow(color: .black.opacity(isDragging ? 0.28 : 0), radius: isDragging ? 10 : 0, y: 4)
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.8), value: isDragging)
        .onHover { hovering in
            hovered = hovering
        }
        .onDrag {
            isDragging = true
            return NSItemProvider(object: item.sourceURL as NSURL)
        }
        .onDrop(of: [.url], isTargeted: nil) { _ in
            // Local drop-back ends the lift; the handler is a no-op returning true.
            isDragging = false
            return true
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accentRing: some View {
        // freshly captured resting items get a brief warm ring hint
        Group {
            if item.status == .resting, !copiedFlash {
                RoundedRectangle(cornerRadius: 12).stroke(.orange.opacity(0.0))
            } else if copiedFlash {
                RoundedRectangle(cornerRadius: 12).stroke(.tint, lineWidth: 1.5)
            } else {
                EmptyView()
            }
        }
    }

    private var hoverToolbar: some View {
        // Toolbar fades in on hover; stays for pinned items.
        Group {
            if hovered || item.status == .pinned {
                HStack(spacing: 4) {
                    toolbarButton("doc.on.doc", help: "Copy image") {
                        onCopyImage()
                        flashCopied()
                    }
                    ShareLink(item: item.sourceURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Share")
                    .accessibilityLabel("Share \(item.displayName)")
                    .buttonStyle(.borderless)
                    toolbarButton(item.status == .pinned ? "pin.slash" : "pin",
                                  help: item.status == .pinned ? "Unpin" : "Pin") {
                        onPin()
                    }
                    .foregroundStyle(item.status == .pinned ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    toolbarButton("xmark", help: "Stow") { onStow() }
                }
                .imageScale(.small)
                .font(.system(size: 13))
            }
        }
    }

    private func toolbarButton(_ system: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system).foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(help)
    }

    private func flashCopied() {
        copiedFlash = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            copiedFlash = false
        }
    }

    private var accessibilityLabel: String {
        var parts = [item.displayName]
        if let app = item.appName { parts.append(app) }
        parts.append(item.capturedAt.formatted(date: .omitted, time: .shortened))
        if item.status == .pinned { parts.append("pinned") }
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
