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

    enum Sidebar: Hashable {
        case timeline, all
        case folder(String)
        case collection(UUID)
    }

    @State private var selection: Sidebar = .all

    private var allItems: [ShelfItem] { model.surfaced }

    private var filtered: [ShelfItem] {
        switch selection {
        case .all, .timeline:
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
            if case .timeline = selection {
                timeline
            } else {
                grid(filtered)
                    .navigationTitle(title)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
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
                    LibraryCard(item: item)
                }
            }
            .padding()
        }
    }

    private var title: String {
        switch selection {
        case .all: return "All Screenshots"
        case .timeline: return "Timeline"
        case .folder(let name): return name
        case .collection(let id): return collections.collections.first(where: { $0.id == id })?.name ?? "Collection"
        }
    }
}

private struct LibraryCard: View {
    let item: ShelfItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ThumbnailView(url: item.sourceURL)
                .frame(height: 90)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(item.displayName)
                .font(.caption)
                .lineLimit(2)
        }
        .accessibilityLabel(item.displayName)
    }
}
