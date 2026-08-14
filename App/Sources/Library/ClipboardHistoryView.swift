import SwiftUI
import AppKit
import SnapShelfRuntime
import SnapShelfTypes

// Sprint 7: Smart Clipboard history grid. Click an entry to put it back on
// the pasteboard; entries are local-only (downscaled PNG, capped history).

struct ClipboardHistoryView: View {
    @State var model: ClipboardHistoryModel

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.entries) { entry in
                    ClipboardEntryCard(entry: entry) {
                        _ = model.copyBack(entry)
                    } onDelete: {
                        Task { await model.remove(entry) }
                    }
                }
            }
            .padding()
        }
        .overlay {
            if model.entries.isEmpty {
                ContentUnavailableView(
                    "No Clipboard History",
                    systemImage: "clipboard",
                    description: Text("Copy an image and it will appear here (local-only).")
                )
            }
        }
        .navigationTitle("Clipboard")
        .toolbar {
            Button(role: .destructive) {
                Task { await model.clear() }
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(model.entries.isEmpty)
        }
        .onAppear {
            model.start()
            Task { await model.refresh() }
        }
        .onDisappear { model.stop() }
    }
}

private struct ClipboardEntryCard: View {
    let entry: ClipboardEntry
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var image: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(height: 90)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(entry.copiedAt, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onCopy)
        .contextMenu {
            Button("Copy", action: onCopy)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityLabel("Clipboard entry from \(entry.copiedAt.formatted())")
        .task(id: entry.id) {
            image = NSImage(data: entry.image)
        }
    }
}
