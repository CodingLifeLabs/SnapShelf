import XCTest
@testable import SnapShelfRepo
@testable import SnapShelfTypes

final class SQLiteShelfRepositoryTests: XCTestCase {

    private func makeRepo() throws -> (SQLiteShelfRepository, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-sqlite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let db = dir.appendingPathComponent("index.sqlite", isDirectory: false)
        let repo = try SQLiteShelfRepository(databaseURL: db)
        return (repo, dir)
    }

    private func item(_ name: String, ocr: String? = nil, captured: TimeInterval = 100) -> ShelfItem {
        ShelfItem(
            sourceURL: URL(fileURLWithPath: "/tmp/\(name)"),
            displayName: name,
            capturedAt: Date(timeIntervalSince1970: captured),
            ocrText: ocr
        )
    }

    // MARK: - CRUD

    func test_upsertAndLoad_returnsItem() async throws {
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

        let names = try await repo.load().map(\.displayName)
        XCTAssertEqual(names, ["new.png", "mid.png", "old.png"])
    }

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

    func test_recent_limits() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }
        try await repo.upsertAll((0..<5).map { item("s\($0).png", captured: Double($0)) })
        let recent = try await repo.recent(2)
        XCTAssertEqual(recent.count, 2)
    }

    func test_delete_removesItem() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }
        let target = item("gone.png")
        try await repo.upsert(target)
        try await repo.delete(id: target.id)
        let remaining = try await repo.load()
        XCTAssertTrue(remaining.isEmpty)
    }

    func test_persistence_survivesNewInstance() async throws {
        let (repo, dir) = try makeRepo()
        let dbPath = repo.databasePathForTesting
        defer { try? FileManager.default.removeItem(at: dir) }

        try await repo.upsert(item("persist.png"))
        let reopened = try SQLiteShelfRepository(databaseURL: URL(fileURLWithPath: dbPath))
        let persisted = try await reopened.load()
        XCTAssertEqual(persisted.first?.displayName, "persist.png")
    }

    // MARK: - FTS5 search

    func test_setOCR_indexesForSearch() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }

        let it = item("shot.png")
        try await repo.upsert(it)
        try await repo.setOCR(id: it.id, text: "Supabase login error code 401")

        let results = try await repo.searchExcerpts("Supabase", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.item.id, it.id)
        XCTAssertTrue(results.first?.excerpt.lowercased().contains("supabase") ?? false)
    }

    func test_search_matchesDisplayNameAndOcr() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }

        try await repo.upsert(item("Stripe Dashboard.png", ocr: "monthly revenue"))
        try await repo.upsert(item("notes.png", ocr: "grocery list"))

        let stripe = try await repo.search("Stripe", limit: 10)
        XCTAssertEqual(stripe.count, 1)
        XCTAssertEqual(stripe.first?.displayName, "Stripe Dashboard.png")

        let revenue = try await repo.search("revenue", limit: 10)
        XCTAssertEqual(revenue.first?.displayName, "Stripe Dashboard.png")
    }

    func test_search_emptyQueryReturnsNothing() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }
        try await repo.upsert(item("a.png", ocr: "hello"))
        let empty = try await repo.search("", limit: 10)
        XCTAssertTrue(empty.isEmpty)
        let spaces = try await repo.search("   ", limit: 10)
        XCTAssertTrue(spaces.isEmpty)
    }

    func test_setOCR_updatingTextReindexes() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }
        let it = item("a.png")
        try await repo.upsert(it)
        try await repo.setOCR(id: it.id, text: "old keyword")
        try await repo.setOCR(id: it.id, text: "new keyword")
        // old should no longer match; new should
        let oldMatches = try await repo.search("old", limit: 10)
        XCTAssertTrue(oldMatches.isEmpty)
        let newMatches = try await repo.search("new", limit: 10)
        XCTAssertEqual(newMatches.count, 1)
    }

    // MARK: - ftsQuery sanitizer

    func test_ftsQuery_quotesTokensAndRejectsEmpty() {
        XCTAssertEqual(SQLiteShelfRepository.ftsQuery("Supabase error"), "\"Supabase\" \"error\"")
        XCTAssertNil(SQLiteShelfRepository.ftsQuery(""))
        XCTAssertNil(SQLiteShelfRepository.ftsQuery("   "))
        // embedded quotes are neutralized (quote -> space -> two tokens)
        XCTAssertEqual(SQLiteShelfRepository.ftsQuery("a\"b"), "\"a\" \"b\"")
    }
}
