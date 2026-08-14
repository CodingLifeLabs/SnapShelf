import XCTest
@testable import SnapShelfRepo
@testable import SnapShelfTypes

final class FileShelfRepositoryTests: XCTestCase {

    private func makeRepo() throws -> (FileShelfRepository, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-repo-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = dir.appendingPathComponent("index.json", isDirectory: false)
        return (FileShelfRepository(storeFile: store), dir)
    }

    private func item(_ name: String, captured: TimeInterval) -> ShelfItem {
        ShelfItem(
            sourceURL: URL(fileURLWithPath: "/tmp/\(name)"),
            displayName: name,
            capturedAt: Date(timeIntervalSince1970: captured)
        )
    }

    // MARK: - Upsert + load

    func test_upsert_thenLoad_returnsItem() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }

        try await repo.upsert(item("a.png", captured: 100))

        let loaded = try await repo.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.displayName, "a.png")
    }

    func test_load_isNewestFirst() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }

        try await repo.upsert(item("old.png", captured: 100))
        try await repo.upsert(item("new.png", captured: 300))
        try await repo.upsert(item("mid.png", captured: 200))

        let loaded = try await repo.load().map(\.displayName)
        XCTAssertEqual(loaded, ["new.png", "mid.png", "old.png"])
    }

    // MARK: - Idempotency / persistence

    func test_upsertSameId_replacesInPlace() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }

        let id = UUID()
        let first = ShelfItem(id: id, sourceURL: URL(fileURLWithPath: "/tmp/a.png"), displayName: "a", status: .resting)
        try await repo.upsert(first)

        var changed = first
        changed.status = .pinned
        try await repo.upsert(changed)

        let loaded = try await repo.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.status, .pinned)
    }

    func test_persistence_survivesNewInstance() async throws {
        let (repo, dir) = try makeRepo()
        let store = repo.storeFileForTesting
        defer { try? FileManager.default.removeItem(at: dir) }

        try await repo.upsert(item("persist.png", captured: 100))

        let reopened = FileShelfRepository(storeFile: store)
        let loaded = try await reopened.load()
        XCTAssertEqual(loaded.first?.displayName, "persist.png")
    }

    // MARK: - Delete + recent

    func test_delete_removesItem() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }

        let target = item("gone.png", captured: 100)
        try await repo.upsert(target)
        try await repo.delete(id: target.id)

        let loaded = try await repo.load()
        XCTAssertTrue(loaded.isEmpty)
    }

    func test_recent_limitsToN() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }

        try await repo.upsertAll((0..<10).map { item("s\($0).png", captured: Double($0)) })
        let recent = try await repo.recent(3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent.first?.displayName, "s9.png") // newest
    }

    func test_recent_zeroReturnsEmpty() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }
        try await repo.upsert(item("a.png", captured: 1))
        let recent = try await repo.recent(0)
        XCTAssertTrue(recent.isEmpty)
    }

    func test_emptyStore_loadsClean() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }
        let loaded = try await repo.load()
        XCTAssertTrue(loaded.isEmpty)
    }
}
