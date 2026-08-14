import XCTest
import SQLite3
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

    // MARK: - Notes (Sprint 7)

    func test_setNote_persistsAndReloads() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }
        let it = item("noted.png")
        try await repo.upsert(it)

        try await repo.setNote(id: it.id, text: "invoice for March")

        let loaded = try await repo.load()
        XCTAssertEqual(loaded.first?.note, "invoice for March")
    }

    func test_setNote_clearingRemovesNote() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }
        let it = item("noted.png", ocr: nil, captured: 10)
        try await repo.upsert(it)
        try await repo.setNote(id: it.id, text: "temporary")

        try await repo.setNote(id: it.id, text: nil)

        let loaded = try await repo.load()
        XCTAssertNil(loaded.first?.note)
    }

    func test_setNote_isSearchable() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }
        let it = item("shot.png")
        try await repo.upsert(it)
        try await repo.setNote(id: it.id, text: "renew passport before trip")

        let results = try await repo.search("passport", limit: 10)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, it.id)
    }

    func test_upsert_roundTripsNote() async throws {
        let (repo, dir) = try makeRepo()
        defer { try? FileManager.default.removeItem(at: dir) }

        var it = item("noted.png")
        it.note = "design review feedback"
        try await repo.upsert(it)

        let loaded = try await repo.load()
        XCTAssertEqual(loaded.first?.note, "design review feedback")
    }

    func test_migration_oldV1DatabaseGainsNoteColumn() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-sqlite-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("index.sqlite", isDirectory: false)

        // Create a legacy v1 schema (no note column) with a real row.
        let legacyID = UUID()
        let raw = try SQLite3Raw(path: dbURL.path)
        try raw.exec("""
            CREATE TABLE shelf_items (
                id TEXT PRIMARY KEY,
                source_url TEXT NOT NULL,
                display_name TEXT NOT NULL,
                original_name TEXT,
                captured_at INTEGER NOT NULL,
                ingested_at INTEGER NOT NULL,
                app_name TEXT,
                category TEXT,
                status TEXT NOT NULL DEFAULT 'resting',
                ocr_text TEXT
            );
            CREATE TABLE schema_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
            INSERT INTO schema_meta(key, value) VALUES('version', '1');
            INSERT INTO shelf_items VALUES('\(legacyID.uuidString)','file:///old.png','old.png',NULL,1,1,NULL,NULL,'resting',NULL);
            """)

        // Reopening runs the migration; note is readable and writable.
        let migrated = try SQLiteShelfRepository(databaseURL: dbURL)
        let loaded = try await migrated.load()
        XCTAssertEqual(loaded.first?.id, legacyID)
        XCTAssertEqual(loaded.first?.displayName, "old.png")
        XCTAssertNil(loaded.first?.note)

        try await migrated.setNote(id: legacyID, text: "migrated note")
        let reloaded = try await migrated.load()
        XCTAssertEqual(reloaded.first?.note, "migrated note")
    }
}

/// Minimal raw sqlite3 handle for creating legacy schemas in migration tests.
private final class SQLite3Raw {
    private var db: OpaquePointer?

    init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            throw SQLiteError.open("cannot open \(path)")
        }
        self.db = handle
    }

    deinit { sqlite3_close(db) }

    func exec(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw SQLiteError.exec(String(cString: sqlite3_errmsg(db)))
        }
    }
}
