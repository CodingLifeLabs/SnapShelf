import Foundation
import SnapShelfTypes
import SnapShelfConfig
import SnapShelfRepo
import SnapShelfService

/// Per-folder watch outcome, surfaced to the Settings UI.
public struct FolderWatchState: Sendable, Equatable, Identifiable {
    public enum State: Sendable, Equatable {
        case watching
        case denied
    }

    public let path: String
    public let state: State

    public var id: String { path }

    public init(path: String, state: State) {
        self.path = path
        self.state = state
    }
}

/// Observable app state that ties the watcher -> pipeline -> repository together
/// and drives the SwiftUI shelf surface. MainActor-isolated for UI safety.
@MainActor
@Observable
public final class ShelfModel {
    public private(set) var surfaced: [ShelfItem] = []
    public private(set) var statusMessage: String = ""
    public private(set) var isWatching: Bool = false
    public private(set) var searchResults: [SearchResult] = []
    public private(set) var isSearching = false
    /// ADR-0011: one entry per watched folder (screenshot folders + Inbox).
    public private(set) var watchedFolderStates: [FolderWatchState] = []

    public let paths: AppPaths
    public let settings: ShelfSettings

    private let repository: any ShelfItemRepository
    private let pipeline: any IntakePipeline
    private let folderSource: any ScreenshotFolderSource
    private var watchers: [any ScreenshotWatcher] = []
    private var stowWork: [UUID: Task<Void, Never>] = [:]

    public init(
        paths: AppPaths,
        settings: ShelfSettings = .default,
        repository: any ShelfItemRepository,
        pipeline: any IntakePipeline,
        folderSource: any ScreenshotFolderSource = DefaultScreenshotFolderSource()
    ) {
        self.paths = paths
        self.settings = settings
        self.repository = repository
        self.pipeline = pipeline
        self.folderSource = folderSource
    }

    // MARK: - Lifecycle

    public func bootstrap(extraFolders: [String] = []) async {
        do {
            try paths.ensureExists()
            await load()
            await startWatchers(extraFolders: extraFolders)
            statusMessage = watchStatusMessage()
        } catch {
            statusMessage = "Setup failed: \(error)"
        }
    }

    /// Human-readable watch state for the status surface.
    public func watchStatusMessage() -> String {
        let watching = watchedFolderStates.filter { $0.state == .watching }.count
        let denied = watchedFolderStates.count - watching
        if denied > 0 {
            return "Watching \(watching) folder(s); \(denied) need permission (see Settings)"
        }
        return "Watching \(watching) folder(s)"
    }

    public func load() async {
        do {
            surfaced = try await repository.recent(settings.historyLimit)
            enforceHistoryLimit()
        } catch {
            statusMessage = "Load failed: \(error)"
        }
    }

    // MARK: - Intake

    /// Ingest a newly detected file. Safe to call from the watcher callback.
    public func ingest(url: URL) async {
        do {
            let item = try await pipeline.ingest(url: url)
            surfaced.insert(item, at: 0)
            enforceHistoryLimit()
            scheduleAutoStow(for: item.id)
        } catch {
            statusMessage = "Ingest failed: \(error)"
        }
    }

    /// Writes a placeholder screenshot into the inbox; the watcher then shelves it.
    @discardableResult
    public func simulateCapture() -> Bool {
        let name = "Simulated-\(Self.filenameTimestamp()).png"
        let url = paths.inboxDirectory.appendingPathComponent(name)
        do {
            let data = try PlaceholderImage.pngData(width: 480, height: 300)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            statusMessage = "Simulate failed: \(error)"
            return false
        }
    }

    public func togglePin(id: UUID) {
        guard let index = surfaced.firstIndex(where: { $0.id == id }) else { return }
        var item = surfaced[index]
        item.status = item.status == .pinned ? .resting : .pinned
        surfaced[index] = item
        if item.status == .pinned { stowWork[id]?.cancel(); stowWork[id] = nil }
        Task { try? await repository.upsert(item) }
    }

    public func stow(id: UUID) {
        stowWork[id]?.cancel()
        stowWork[id] = nil
        guard let index = surfaced.firstIndex(where: { $0.id == id }) else { return }
        var item = surfaced[index]
        item.status = .stowed
        surfaced[index] = item
        Task { try? await repository.upsert(item) }
    }

    public var visibleItems: [ShelfItem] {
        surfaced.filter { $0.isSurfaced }
    }

    // MARK: - Notes

    /// Attach (or clear, when empty) a user note on an item and persist it.
    public func saveNote(id: UUID, text: String) async {
        guard let index = surfaced.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var item = surfaced[index]
        item.note = trimmed.isEmpty ? nil : trimmed
        surfaced[index] = item
        do {
            try await repository.setNote(id: id, text: item.note)
        } catch {
            statusMessage = "Save note failed: \(error)"
        }
    }

    // MARK: - Search

    public func runSearch(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { searchResults = []; return }
        isSearching = true
        defer { isSearching = false }
        do {
            searchResults = try await repository.searchExcerpts(trimmed, limit: 50)
        } catch {
            statusMessage = "Search failed: \(error)"
        }
    }

    public func clearSearch() {
        searchResults = []
    }

    /// Always-on-shelf items shown in a dedicated top section.
    public var pinned: [ShelfItem] {
        surfaced.filter { $0.status == .pinned }
    }

    /// Freshly captured, not pinned — the scrolling section.
    public var recent: [ShelfItem] {
        surfaced.filter { $0.status == .resting }
    }

    /// Pure policy: should a resting item auto-stow after the hover window?
    public static func shouldAutoStow(_ item: ShelfItem, settings: ShelfSettings) -> Bool {
        settings.autoStow && item.status == .resting
    }

    /// Schedule auto-stow for a resting item (cancels any prior schedule for it).
    public func scheduleAutoStow(for id: UUID) {
        guard let item = surfaced.first(where: { $0.id == id }),
              Self.shouldAutoStow(item, settings: settings) else { return }
        stowWork[id]?.cancel()
        let seconds = settings.hoverSeconds
        stowWork[id] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.stow(id: id)
        }
    }

    /// Keep pinned items always; trim oldest non-pinned beyond `historyLimit`.
    public func enforceHistoryLimit() {
        let limit = settings.historyLimit
        guard surfaced.count > limit else { return }
        let nonPinnedBudget = max(0, limit - surfaced.filter { $0.status == .pinned }.count)
        var kept: [ShelfItem] = []
        var nonPinnedKept = 0
        for item in surfaced { // surfaced is newest-first
            if item.status == .pinned {
                kept.append(item)
            } else if nonPinnedKept < nonPinnedBudget {
                kept.append(item)
                nonPinnedKept += 1
            }
        }
        surfaced = kept
    }

    // MARK: - Internals

    /// ADR-0011: watch every resolved screenshot folder plus the app Inbox.
    /// Each folder gets its own DirectoryWatcher; a folder that cannot be
    /// opened (e.g. TCC denial) is marked `denied` without stopping the rest.
    /// - Parameter extraFolders: user-added folders (from AppSettings.watchedFolders).
    public func startWatchers(extraFolders: [String] = []) async {
        let resolved = folderSource.watchedFolders(userFolders: extraFolders)
            .filter { !ScreenshotFolders.isProtected($0, appPaths: paths) }
        var dirs = resolved.map { URL(fileURLWithPath: $0, isDirectory: true) }
        if !dirs.contains(where: { $0.path == paths.inboxDirectory.path }) {
            dirs.append(paths.inboxDirectory)
        }

        // Stop any previous watchers before switching folder sets.
        for watcher in watchers { Task { await watcher.stop() } }
        watchedFolderStates = []
        var started: [any ScreenshotWatcher] = []
        for dir in dirs {
            let watcher = DirectoryWatcher(directory: dir) { [weak self] url in
                Task { @MainActor [weak self] in await self?.ingest(url: url) }
            }
            do {
                try await watcher.start()
                started.append(watcher)
                watchedFolderStates.append(FolderWatchState(path: dir.path, state: .watching))
            } catch {
                watchedFolderStates.append(FolderWatchState(path: dir.path, state: .denied))
            }
        }
        watchers = started
        isWatching = !started.isEmpty
    }

    private static func filenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }
}
