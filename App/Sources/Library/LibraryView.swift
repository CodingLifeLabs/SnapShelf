import SwiftUI
import SnapShelfRuntime
import SnapShelfService
import SnapShelfTypes

// Sprint 6: Library window — sidebar (Timeline / All / Smart Folders / Collections) + content.
// Visual interaction is verified in an interactive environment; logic is unit-tested.

struct LibraryView: View {
    let model: ShelfModel
    let library: LibraryModel
    let collections: CollectionModel
    @State var cleanup: CleanupModel
    @State var duplicates: DuplicatesModel
    @State var clipboard: ClipboardHistoryModel

    enum Sidebar: Hashable {
        case timeline, all, duplicates, clipboard
        case folder(String)
        case collection(UUID)
    }

    @State private var selection: Sidebar = .all
    @State private var noteTarget: ShelfItem?

    private var allItems: [ShelfItem] { model.surfaced }

    private var filtered: [ShelfItem] {
        switch selection {
        case .all, .timeline, .duplicates, .clipboard:
            return allItems
        case .folder(let name):
            return allItems.filter { $0.sourceURL.path.contains("/Library/\(name)/") }
        case .collection(let id):
            return collections.items(in: id, from: allItems)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            switch selection {
            case .timeline:
                timeline
            case .duplicates:
                DuplicatesView(model: model, cleanup: cleanup, duplicates: duplicates)
            case .clipboard:
                ClipboardHistoryView(model: clipboard)
            default:
                grid(filtered)
                    .navigationTitle(title)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .sheet(item: $noteTarget) { item in
            NoteEditorView(item: item) { text in
                await model.saveNote(id: item.id, text: text)
            }
        }
        .onAppear {
            library.refresh()
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("View") {
                Label("Timeline", systemImage: "clock").tag(Sidebar.timeline)
                Label("All Screenshots", systemImage: "photo.on.rectangle").tag(Sidebar.all)
            }
            Section("Tools") {
                Label("Duplicates & Cleanup", systemImage: "square.stack.3d.up.slash").tag(Sidebar.duplicates)
                Label("Clipboard", systemImage: "clipboard").tag(Sidebar.clipboard)
            }
            if !library.folders.isEmpty {
                Section("Smart Folders") {
                    ForEach(library.folders, id: \.self) { folder in
                        Label(folder, systemImage: "folder").tag(Sidebar.folder(folder))
                    }
                }
            }
            if !collections.collections.isEmpty {
                Section("Collections") {
                    ForEach(collections.collections) { collection in
                        Label(collection.name, systemImage: "square.stack").tag(Sidebar.collection(collection.id))
                    }
                }
            }
        }
    }

    private var timeline: some View {
        let buckets = TimelineGrouper.group(filtered)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if buckets.isEmpty {
                    Text("No items to show on the timeline.").foregroundStyle(.secondary).padding()
                }
                ForEach(buckets) { bucket in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bucket.label).font(.headline)
                        grid(bucket.items)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Timeline")
    }

    private func grid(_ items: [ShelfItem]) -> some View {
        let columns = [GridItem(.adaptive(minimum: 130), spacing: 12)]
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    LibraryCard(item: item, onEditNote: { noteTarget = item })
                }
            }
            .padding()
        }
    }

    private var title: String {
        switch selection {
        case .all: return "All Screenshots"
        case .timeline: return "Timeline"
        case .duplicates: return "Maintenance"
        case .clipboard: return "Clipboard"
        case .folder(let name): return name
        case .collection(let id): return collections.collections.first(where: { $0.id == id })?.name ?? "Collection"
        }
    }
}

private struct LibraryCard: View {
    let item: ShelfItem
    let onEditNote: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ThumbnailView(url: item.sourceURL)
                .frame(height: 90)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(item.displayName)
                .font(.caption)
                .lineLimit(2)
            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button("Edit Note…", action: onEditNote)
        }
        .accessibilityLabel(item.displayName)
    }
}
