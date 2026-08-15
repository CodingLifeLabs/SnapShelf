import SwiftUI
import SnapShelfRuntime
import SnapShelfService
import SnapShelfTypes

struct ShelfView: View {
    let model: ShelfModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clipboard = ClipboardService()
    @State private var query = ""
    @State private var appeared = false

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchBar
            if isSearching {
                searchContent
            } else {
                content
            }
        }
        .background(.ultraThinMaterial)
        .frame(width: 340, height: 460)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Shelf")
                    .font(.headline)
                Text(model.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                _ = model.simulateCapture()
            } label: {
                Label("Capture", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Write a placeholder screenshot into the inbox (simulates ⌘⇧4)")
        }
        .padding(12)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search screenshots by text…", text: $query)
                .textFieldStyle(.plain)
                .onSubmit { Task { await model.runSearch(query) } }
            if !query.isEmpty {
                Button {
                    query = ""
                    model.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .padding([.horizontal, .top], 12)
        .onChange(of: query) { _, newValue in
            Task { await model.runSearch(newValue) }
        }
    }

    @ViewBuilder private var content: some View {
        if model.pinned.isEmpty, model.recent.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if !model.pinned.isEmpty {
                        section(title: "Pinned", items: model.pinned)
                    }
                    if !model.recent.isEmpty || model.pinned.isEmpty {
                        section(title: "Recent", items: model.recent)
                    }
                }
                .padding(12)
            }
            .animation(reduceMotion ? nil : spring, value: sectionKey)
        }
    }

    @ViewBuilder private var searchContent: some View {
        if model.isSearching {
            ProgressView("Searching…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.searchResults.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
                Text("No matches for “\(query)”").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(model.searchResults.enumerated()), id: \.element.item.id) { index, result in
                        resultRow(result)
                            .opacity((reduceMotion || appeared) ? 1 : 0)
                            .offset(y: (reduceMotion || appeared) ? 0 : 6)
                            .task {
                                guard !reduceMotion else { return }
                                try? await Task.sleep(nanoseconds: UInt64(index) * 12_000_000)
                                withAnimation(.easeOut(duration: 0.18)) { appeared = true }
                            }
                    }
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ result: SearchResult) -> some View {
        HStack(spacing: 10) {
            ThumbnailView(url: result.item.sourceURL)
                .frame(width: 48, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(result.item.displayName).font(.caption.weight(.semibold)).lineLimit(1)
                Text(result.excerpt).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
    }

    @ViewBuilder
    private func section(title: String, items: [ShelfItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            ForEach(items) { item in
                ShelfItemView(
                    item: item,
                    reduceMotion: reduceMotion,
                    onPin: { model.togglePin(id: item.id) },
                    onStow: { model.stow(id: item.id) },
                    onCopyImage: { clipboard.copyImage(at: item.sourceURL) }
                )
                .transition(itemTransition)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Nothing shelved yet")
                .font(.title3)
                .bold()
            Text("Press ⌘⇧4 to capture, or tap Capture to simulate one.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Simulate Capture") {
                _ = model.simulateCapture()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    private var sectionKey: [UUID] {
        model.pinned.map(\.id) + model.recent.map(\.id)
    }

    private var spring: Animation { .spring(response: 0.4, dampingFraction: 0.82) }

    private var itemTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal: .opacity
            )
    }
}
