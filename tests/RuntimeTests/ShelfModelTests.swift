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
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-model-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let paths = AppPaths(
            supportDirectory: dir,
            inboxDirectory: dir.appendingPathComponent("Inbox", isDirectory: true),
            libraryDirectory: dir.appendingPathComponent("Library", isDirectory: true),
            storeFile: dir.appendingPathComponent("index.json", isDirectory: false)
        )
        try paths.ensureExists()
        let repo = FakeRepo()
        let pipeline = FakePipeline()
        let model = ShelfModel(paths: paths, settings: settings, repository: repo, pipeline: pipeline)
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
}
