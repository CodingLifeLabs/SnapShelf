import Foundation
import SnapShelfTypes
import SnapShelfConfig
import SnapShelfRepo
import SnapShelfService

/// Observable app state that ties the watcher -> pipeline -> repository together
/// and drives the SwiftUI shelf surface. MainActor-isolated for UI safety.
@MainActor
@Observable
public final class ShelfModel {
    public private(set) var surfaced: [ShelfItem] = []
    public private(set) var statusMessage: String = ""
    public private(set) var isWatching: Bool = false

    public let paths: AppPaths
    public let settings: ShelfSettings

    private let repository: any ShelfItemRepository
    private let pipeline: any IntakePipeline
    private var watcher: (any ScreenshotWatcher)?

    public init(
        paths: AppPaths,
        settings: ShelfSettings = .default,
        repository: any ShelfItemRepository,
        pipeline: any IntakePipeline
    ) {
        self.paths = paths
        self.settings = settings
        self.repository = repository
        self.pipeline = pipeline
    }

    // MARK: - Lifecycle

    public func bootstrap() async {
        do {
            try paths.ensureExists()
            await load()
            try await startWatcher()
            statusMessage = "Watching \(paths.inboxDirectory.lastPathComponent)/"
        } catch {
            statusMessage = "Setup failed: \(error)"
        }
    }

    public func load() async {
        do {
            surfaced = try await repository.recent(settings.historyLimit)
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
        Task { try? await repository.upsert(item) }
    }

    public func stow(id: UUID) {
        guard let index = surfaced.firstIndex(where: { $0.id == id }) else { return }
        var item = surfaced[index]
        item.status = .stowed
        surfaced[index] = item
        Task { try? await repository.upsert(item) }
    }

    public var visibleItems: [ShelfItem] {
        surfaced.filter { $0.isSurfaced }
    }

    // MARK: - Internals

    private func startWatcher() async throws {
        let dir = paths.inboxDirectory
        let watcher = DirectoryWatcher(directory: dir) { [weak self] url in
            Task { @MainActor [weak self] in await self?.ingest(url: url) }
        }
        try await watcher.start()
        self.watcher = watcher
        isWatching = true
    }

    private static func filenameTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }
}
