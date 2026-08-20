import XCTest
@testable import SnapShelfRuntime
@testable import SnapShelfRepo
@testable import SnapShelfService
@testable import SnapShelfTypes

final class CleanupModelTests: XCTestCase {

    private struct FakeTrashStore: TrashStore {
        let trashDir: URL

        func trash(_ url: URL) async throws -> URL? {
            let dest = trashDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: dest)
            return dest
        }

        func restore(from trashURL: URL?, to originalURL: URL) async throws {
            guard let trashURL else { throw AutoCleanupError.unknownTrashLocation(originalURL) }
            try FileManager.default.moveItem(at: trashURL, to: originalURL)
        }
    }

    private actor FakeRepo: ShelfItemRepository {
        private var storage: [UUID: ShelfItem] = [:]
        func load() async throws -> [ShelfItem] { Array(storage.values) }
        func upsert(_ item: ShelfItem) async throws { storage[item.id] = item }
        func upsertAll(_ items: [ShelfItem]) async throws { for item in items { storage[item.id] = item } }
        func delete(id: UUID) async throws { storage[id] = nil }
        func recent(_ limit: Int) async throws -> [ShelfItem] { Array(storage.values.prefix(limit)) }
        func search(_ query: String, limit: Int) async throws -> [ShelfItem] { [] }
        func searchExcerpts(_ query: String, limit: Int) async throws -> [SearchResult] { [] }
        func setOCRStatus(id: UUID, status: OCRStatus?) async throws { }
        func setOCR(id: UUID, text: String?) async throws {}
        func setNote(id: UUID, text: String?) async throws {}
        func find(_ id: UUID) async throws -> ShelfItem? { storage[id] }
    }

    private struct Env {
        let model: CleanupModel
        let repo: FakeRepo
        let dir: URL
        let trashDir: URL
    }

    @MainActor
    private func makeEnv() throws -> Env {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cleanup-model-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let trashDir = dir.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true)
        let now = Date(timeIntervalSince1970: 1_000_000)
        let repo = FakeRepo()
        let model = CleanupModel(
            repository: repo,
            service: AutoCleanupService(
                policy: AutoCleanupPolicy(retentionDays: 30, now: now),
                trash: FakeTrashStore(trashDir: trashDir)
            )
        )
        return Env(model: model, repo: repo, dir: dir, trashDir: trashDir)
    }

    @MainActor
    func test_runCleanup_trashesAndMarksDeleted_thenUndoRestores() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }

        let oldURL = env.dir.appendingPathComponent("old.png")
        try Data([1]).write(to: oldURL)
        let old = ShelfItem(
            sourceURL: oldURL, displayName: "old.png",
            capturedAt: Date(timeIntervalSince1970: 1_000_000).addingTimeInterval(-40 * 86_400)
        )
        try await env.repo.upsert(old)

        await env.model.runCleanup(items: [old])

        XCTAssertEqual(env.model.cleanedCount, 1)
        XCTAssertTrue(env.model.canUndo)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
        let stored = try await env.repo.find(old.id)
        XCTAssertEqual(stored?.status, .deleted)

        await env.model.undoLast()

        XCTAssertTrue(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: env.trashDir.appendingPathComponent("old.png").path))
        let restored = try await env.repo.find(old.id)
        XCTAssertEqual(restored?.status, .resting)
        XCTAssertFalse(env.model.canUndo)
    }

    @MainActor
    func test_runCleanup_nothingEligible() async throws {
        let env = try makeEnv()
        defer { try? FileManager.default.removeItem(at: env.dir) }

        let fresh = ShelfItem(
            sourceURL: env.dir.appendingPathComponent("fresh.png"),
            displayName: "fresh.png",
            capturedAt: Date(timeIntervalSince1970: 1_000_000)
        )
        try await env.repo.upsert(fresh)

        await env.model.runCleanup(items: [fresh])

        XCTAssertEqual(env.model.cleanedCount, 0)
        XCTAssertFalse(env.model.canUndo)
    }
}
