import XCTest
@testable import SnapShelfRuntime
@testable import SnapShelfConfig
@testable import SnapShelfRepo
@testable import SnapShelfService
@testable import SnapShelfTypes

@MainActor
final class ShelfModelTests: XCTestCase {

    private actor FakeRepo: ShelfItemRepository {
        private var storage: [UUID: ShelfItem] = [:]
        func load() async throws -> [ShelfItem] { Array(storage.values) }
        func upsert(_ item: ShelfItem) async throws { storage[item.id] = item }
        func upsertAll(_ items: [ShelfItem]) async throws { for item in items { storage[item.id] = item } }
        func delete(id: UUID) async throws { storage[id] = nil }
        func recent(_ limit: Int) async throws -> [ShelfItem] {
            Array(storage.values)
                .sorted { $0.capturedAt > $1.capturedAt }
                .prefix(limit)
                .map { $0 }
        }
        func search(_ query: String, limit: Int) async throws -> [ShelfItem] {
            let q = query.lowercased()
            guard !q.isEmpty else { return [] }
            return Array(storage.values.filter {
                $0.displayName.lowercased().contains(q)
                    || ($0.ocrText?.lowercased().contains(q) ?? false)
            }.prefix(max(0, limit)))
        }
        func searchExcerpts(_ query: String, limit: Int) async throws -> [SearchResult] {
            try await search(query, limit: limit)
                .map { SearchResult(item: $0, excerpt: $0.ocrText ?? $0.displayName) }
        }
        func setOCR(id: UUID, text: String?) async throws {
            if var item = storage[id] { item.ocrText = text; storage[id] = item }
        }
        func setNote(id: UUID, text: String?) async throws {
            if var item = storage[id] { item.note = text; storage[id] = item }
        }
        func find(_ id: UUID) async throws -> ShelfItem? { storage[id] }
    }

    private actor FakePipeline: IntakePipeline {
        func ingest(url: URL) async throws -> ShelfItem {
            ShelfItem(
                sourceURL: url,
                displayName: url.lastPathComponent,
                capturedAt: Date(timeIntervalSince1970: 1)
            )
        }
    }

    private struct ModelEnv {
        let model: ShelfModel
        let repo: FakeRepo
        let pipeline: FakePipeline
        let dir: URL
    }

    private func makeEnv(settings: ShelfSettings = .default) throws -> ModelEnv {
        try makeEnv(settings: settings, folderPaths: [])
    }

    /// Stub folder source resolving fixed paths — keeps tests off the real ~/Desktop.
    private struct StubFolderSource: ScreenshotFolderSource {
        let pathsToWatch: [String]
        func watchedFolders(userFolders: [String]) -> [String] { pathsToWatch }
    }

    /// - Parameters:
    ///   - folderPaths: resolved folders that will be created on disk.
    ///   - uncreatedPaths: resolved folders deliberately left missing (denied path).
    private func makeEnv(
        settings: ShelfSettings = .default,
        folderPaths: [String],
        uncreatedPaths: [String] = []
    ) throws -> ModelEnv {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-model-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for p in folderPaths {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: p, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
        let paths = AppPaths(
            supportDirectory: dir,
            inboxDirectory: dir.appendingPathComponent("Inbox", isDirectory: true),
            libraryDirectory: dir.appendingPathComponent("Library", isDirectory: true),
            storeFile: dir.appendingPathComponent("index.json", isDirectory: false),
            databaseFile: dir.appendingPathComponent("index.sqlite", isDirectory: false),
            clipboardHistoryFile: dir.appendingPathComponent("clipboard-history.json", isDirectory: false),
            recordingsDirectory: dir.appendingPathComponent("Recordings", isDirectory: true),
            privacyLogFile: dir.appendingPathComponent("privacy-log.jsonl", isDirectory: false)
        )
        try paths.ensureExists()
        let repo = FakeRepo()
        let pipeline = FakePipeline()
        let source = StubFolderSource(pathsToWatch: folderPaths + uncreatedPaths)
        let model = ShelfModel(
            paths: paths,
            settings: settings,
            repository: repo,
            pipeline: pipeline,
            folderSource: source
        )
        return ModelEnv(model: model, repo: repo, pipeline: pipeline, dir: dir)
    }

    // MARK: - sections

    func test_pinnedAndRecent_splitByStatus() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }
        await env.model.ingest(url: URL(fileURLWithPath: "/x/a.png"))
        await env.model.ingest(url: URL(fileURLWithPath: "/x/b.png"))
        let firstId = env.model.surfaced.first!.id
        env.model.togglePin(id: firstId)

        XCTAssertEqual(env.model.pinned.count, 1)
        XCTAssertEqual(env.model.recent.count, 1)
        XCTAssertEqual(env.model.pinned.first?.id, firstId)
    }

    // MARK: - history limit

    func test_enforceHistoryLimit_keepsNewestAndPin() async throws {
        let settings = ShelfSettings(hoverSeconds: 999, historyLimit: 3, autoStow: false)
        let env = try makeEnv(settings: settings)
        defer { try? FileManager.default.removeItem(at: env.dir) }

        for i in 0..<6 {
            await env.model.ingest(url: URL(fileURLWithPath: "/x/s\(i).png"))
        }
        // ingest already trims to the limit -> only newest 3 remain
        XCTAssertEqual(env.model.surfaced.count, 3)
        XCTAssertEqual(Set(env.model.surfaced.map(\.displayName)), ["s5.png", "s4.png", "s3.png"])

        // pin the oldest remaining; re-enforcing keeps it while preserving newest order
        let pinId = env.model.surfaced.first(where: { $0.displayName == "s3.png" })!.id
        env.model.togglePin(id: pinId)
        env.model.enforceHistoryLimit()

        XCTAssertTrue(env.model.pinned.contains(where: { $0.id == pinId }))
        XCTAssertEqual(env.model.surfaced.first?.displayName, "s5.png")
    }

    // MARK: - auto-stow policy

    func test_shouldAutoStow_policy() {
        let on = ShelfSettings(hoverSeconds: 1, historyLimit: 10, autoStow: true)
        let off = ShelfSettings(hoverSeconds: 1, historyLimit: 10, autoStow: false)
        let resting = ShelfItem(sourceURL: URL(fileURLWithPath: "/x/a.png"), displayName: "a", status: .resting)
        let pinned = ShelfItem(sourceURL: URL(fileURLWithPath: "/x/a.png"), displayName: "a", status: .pinned)

        XCTAssertTrue(ShelfModel.shouldAutoStow(resting, settings: on))
        XCTAssertFalse(ShelfModel.shouldAutoStow(resting, settings: off))
        XCTAssertFalse(ShelfModel.shouldAutoStow(pinned, settings: on))
    }

    // MARK: - load

    func test_bootstrap_startsWatchingAndSetsStatus() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }

        XCTAssertFalse(env.model.isWatching)
        XCTAssertTrue(env.model.statusMessage.isEmpty)

        await env.model.bootstrap()

        XCTAssertTrue(env.model.isWatching)
        XCTAssertFalse(env.model.statusMessage.isEmpty)
    }

    func test_load_populatesSurfacedFromRepository() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }
        try await env.repo.upsert(ShelfItem(sourceURL: URL(fileURLWithPath: "/x/a.png"), displayName: "a"))

        XCTAssertTrue(env.model.surfaced.isEmpty)
        await env.model.load()
        XCTAssertEqual(env.model.surfaced.count, 1)
    }

    // MARK: - ingest

    func test_ingest_insertsAtFront() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }

        await env.model.ingest(url: URL(fileURLWithPath: "/x/first.png"))
        await env.model.ingest(url: URL(fileURLWithPath: "/x/second.png"))

        XCTAssertEqual(env.model.surfaced.count, 2)
        XCTAssertEqual(env.model.surfaced.first?.displayName, "second.png")
    }

    // MARK: - simulateCapture

    func test_simulateCapture_writesPngIntoInbox() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }

        let result = env.model.simulateCapture()

        XCTAssertTrue(result)
        let inbox = env.model.paths.inboxDirectory
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: inbox.path)) ?? []
        XCTAssertTrue(entries.contains(where: { $0.hasPrefix("Simulated-") && $0.hasSuffix(".png") }))
    }

    // MARK: - notes

    func test_saveNote_setsTrimsAndPersists() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }
        await env.model.ingest(url: URL(fileURLWithPath: "/x/a.png"))
        let id = env.model.surfaced.first!.id
        // FakePipeline does not touch the repo; simulate the pipeline's upsert.
        try await env.repo.upsert(env.model.surfaced.first!)

        await env.model.saveNote(id: id, text: "  invoice for March  ")

        XCTAssertEqual(env.model.surfaced.first?.note, "invoice for March")
        let stored = try await env.repo.find(id)
        XCTAssertEqual(stored?.note, "invoice for March")
    }

    func test_saveNote_emptyTextClearsNote() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }
        await env.model.ingest(url: URL(fileURLWithPath: "/x/a.png"))
        let id = env.model.surfaced.first!.id
        try await env.repo.upsert(env.model.surfaced.first!)
        await env.model.saveNote(id: id, text: "temporary")

        await env.model.saveNote(id: id, text: "   ")

        XCTAssertNil(env.model.surfaced.first?.note)
        let stored = try await env.repo.find(id)
        XCTAssertNil(stored?.note)
    }

    // MARK: - pin / stow

    func test_togglePin_flipsStatus() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }
        await env.model.ingest(url: URL(fileURLWithPath: "/x/a.png"))
        let id = env.model.surfaced.first!.id

        env.model.togglePin(id: id)
        XCTAssertEqual(env.model.surfaced.first?.status, .pinned)
        env.model.togglePin(id: id)
        XCTAssertEqual(env.model.surfaced.first?.status, .resting)
        // Note: persistence is fire-and-forget in the model; the repository itself
        // is covered by FileShelfRepositoryTests.
    }

    func test_visibleItems_excludesStowed() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }
        await env.model.ingest(url: URL(fileURLWithPath: "/x/a.png"))
        await env.model.ingest(url: URL(fileURLWithPath: "/x/b.png"))
        let firstId = env.model.surfaced.first!.id

        env.model.stow(id: firstId)

        XCTAssertEqual(env.model.visibleItems.count, 1)
        XCTAssertFalse(env.model.visibleItems.contains(where: { $0.id == firstId }))
    }

    // MARK: - Sprint 11: multi-folder watching (ADR-0011)

    func test_bootstrap_watchesEveryResolvedFolderPlusInbox() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("watched-\(UUID().uuidString)", isDirectory: true)
        let shots = dir.appendingPathComponent("Shots", isDirectory: true).path
        let caps = dir.appendingPathComponent("Caps", isDirectory: true).path
        let env = try makeEnv(folderPaths: [shots, caps])
        defer { try? FileManager.default.removeItem(at: dir) }

        await env.model.bootstrap()

        XCTAssertTrue(env.model.isWatching)
        let watchingPaths = env.model.watchedFolderStates
            .filter { $0.state == .watching }
            .map(\.path)
        XCTAssertTrue(watchingPaths.contains(shots))
        XCTAssertTrue(watchingPaths.contains(caps))
        XCTAssertTrue(watchingPaths.contains(env.model.paths.inboxDirectory.path))
        XCTAssertEqual(env.model.watchedFolderStates.count, 3)
    }

    func test_bootstrap_deniedFolderDoesNotStopOthers() async throws {
        // Resolved-but-missing path → directory open fails → denied state.
        let missing = "/definitely/not/a/real/place-\(UUID().uuidString)"
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("watched2-\(UUID().uuidString)", isDirectory: true)
        let shots = dir.appendingPathComponent("Shots", isDirectory: true).path
        let env = try makeEnv(folderPaths: [shots], uncreatedPaths: [missing])
        defer { try? FileManager.default.removeItem(at: dir) }

        await env.model.bootstrap()

        // Inbox still watches even though one folder was denied.
        XCTAssertTrue(env.model.isWatching)
        XCTAssertEqual(
            env.model.watchedFolderStates.first { $0.path == missing }?.state,
            .denied
        )
        XCTAssertTrue(env.model.statusMessage.contains("permission"))
    }

    func test_bootstrap_withoutSourcedFoldersStillWatchesInbox() async throws {
        let env = try makeEnv(folderPaths: [])
        defer { try? FileManager.default.removeItem(at: env.dir) }

        await env.model.bootstrap()

        XCTAssertTrue(env.model.isWatching)
        XCTAssertEqual(
            env.model.watchedFolderStates.map(\.path),
            [env.model.paths.inboxDirectory.path]
        )
    }

    func test_startWatchers_restartsProtectsAgainstAppOwnedPaths() async throws {
        let env = try makeEnv(folderPaths: [])
        defer { try? FileManager.default.removeItem(at: env.dir) }
        let inbox = env.model.paths.inboxDirectory.path
        let nested = inbox + "/nested"

        await env.model.startWatchers(extraFolders: [nested])

        // The Inbox appears once — the nested app-owned path must not add a second watcher.
        XCTAssertEqual(
            env.model.watchedFolderStates.filter { $0.path == inbox }.count, 1
        )
        XCTAssertFalse(env.model.watchedFolderStates.contains(where: { $0.path == nested }))
    }

    func test_realFileInWatchedFolderFlowsThroughPipeline() async throws {
        // End-to-end: a file dropped into a watched (non-Inbox) folder gets ingested.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("e2e-\(UUID().uuidString)", isDirectory: true)
        let shots = dir.appendingPathComponent("Shots", isDirectory: true).path
        let env = try makeEnv(folderPaths: [shots])
        defer { try? FileManager.default.removeItem(at: dir) }
        await env.model.bootstrap()

        let png = URL(fileURLWithPath: shots).appendingPathComponent("real-capture.png")
        try PlaceholderImage.pngData(width: 10, height: 10).write(to: png)

        // Watcher fires async; poll briefly for the item to surface.
        for _ in 0..<40 where !env.model.surfaced.contains(where: { $0.sourceURL == png }) {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(
            env.model.surfaced.contains(where: { $0.sourceURL == png }),
            "file in watched folder should surface on the shelf"
        )
    }
}
