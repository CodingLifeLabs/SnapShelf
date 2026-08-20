import Foundation
import SQLite3
import SnapShelfTypes

// Sprint 3: SQLite + FTS5 repository behind the same ShelfItemRepository protocol.
// Uses the system libsqlite3 (FTS5 included on macOS). WAL mode.
// The connection is opened with SQLITE_OPEN_FULLMUTEX (serialized) so it is safe to
// share across the concurrent async entry points; @unchecked Sendable reflects that.

public enum SQLiteError: Error, Equatable {
    case open(String)
    case exec(String)
    case prepare(String)
    case step(String)
}

/// Marks a binding for SQLite to copy (transient ownership).
private let sqliteTransient: sqlite3_destructor_type = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func sqliteErrorMessage(_ db: OpaquePointer?) -> String {
    guard let db, let raw = sqlite3_errmsg(db) else { return "unknown" }
    return String(cString: raw)
}

public final class SQLiteShelfRepository: ShelfItemRepository, @unchecked Sendable {
    private let db: OpaquePointer?
    private let dbPath: String

    public init(databaseURL: URL) throws {
        self.dbPath = databaseURL.path
        let dir = (dbPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: dir, withIntermediateDirectories: true, attributes: nil
        )

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbPath, &handle, flags, nil) != SQLITE_OK {
            let msg = sqliteErrorMessage(handle)
            sqlite3_close(handle)
            throw SQLiteError.open(msg)
        }
        self.db = handle

        do {
            try exec("PRAGMA journal_mode=WAL;")
            try exec("PRAGMA foreign_keys=ON;")
            try createSchema()
            try migrateIfNeeded()
        } catch {
            sqlite3_close(self.db)
            throw error
        }
    }

    deinit { sqlite3_close(db) }

    // MARK: - Setup

    private static let schemaSQL = """
        CREATE TABLE IF NOT EXISTS schema_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS shelf_items (
            id TEXT PRIMARY KEY,
            source_url TEXT NOT NULL,
            display_name TEXT NOT NULL,
            original_name TEXT,
            captured_at INTEGER NOT NULL,
            ingested_at INTEGER NOT NULL,
            app_name TEXT,
            category TEXT,
            status TEXT NOT NULL DEFAULT 'resting',
            ocr_text TEXT,
            ocr_status TEXT,
            note TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_items_captured ON shelf_items(captured_at DESC);
        CREATE VIRTUAL TABLE IF NOT EXISTS shelf_items_fts USING fts5(
            item_id UNINDEXED,
            content,
            tokenize = 'porter unicode61 remove_diacritics 2'
        );
        INSERT OR IGNORE INTO schema_meta(key, value) VALUES('version', '3');
        """

    private func createSchema() throws {
        try exec(Self.schemaSQL)
    }

    /// v1 -> v2: add the `note` column for AI/user notes (Sprint 7).
    /// v2 -> v3: add the `ocr_status` column for OCR outcome visibility (Sprint 13).
    /// CREATE TABLE IF NOT EXISTS does not extend an existing table, so older
    /// databases are upgraded with ALTER TABLE.
    private func migrateIfNeeded() throws {
        let columns = tableInfo("shelf_items")
        if !columns.contains("note") {
            try exec("ALTER TABLE shelf_items ADD COLUMN note TEXT;")
        }
        if !columns.contains("ocr_status") {
            try exec("ALTER TABLE shelf_items ADD COLUMN ocr_status TEXT;")
        }
        try exec("UPDATE schema_meta SET value = '3' WHERE key = 'version';")
    }

    /// Column names of a table via PRAGMA table_info.
    private func tableInfo(_ table: String) -> [String] {
        guard let stmt = try? prepare("PRAGMA table_info(\(table));") else { return [] }
        var names: [String] = []
        while (try? stmt.step()) == true, let name = stmt.text(1) {
            names.append(name)
        }
        return names
    }

    private func exec(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw SQLiteError.exec(sqliteErrorMessage(db))
        }
    }

    // MARK: - ShelfItemRepository

    public func load() async throws -> [ShelfItem] {
        try runQuery("SELECT \(columns) FROM shelf_items WHERE status != 'deleted' ORDER BY captured_at DESC;")
    }

    public func recent(_ limit: Int) async throws -> [ShelfItem] {
        try runQuery(
            "SELECT \(columns) FROM shelf_items WHERE status != 'deleted' ORDER BY captured_at DESC LIMIT ?;",
            binds: { stmt in stmt.bind(1, Int64(max(0, limit))) }
        )
    }

    public func upsert(_ item: ShelfItem) async throws {
        try inTransaction { try self.upsertRow(item) }
    }

    public func upsertAll(_ items: [ShelfItem]) async throws {
        try inTransaction { for item in items { try self.upsertRow(item) } }
    }

    public func delete(id: UUID) async throws {
        try inTransaction {
            try self.exec("DELETE FROM shelf_items_fts WHERE item_id = '\(escape(id.uuidString))';")
            try self.exec("DELETE FROM shelf_items WHERE id = '\(escape(id.uuidString))';")
        }
    }

    public func setOCR(id: UUID, text: String?) async throws {
        try inTransaction {
            try self.exec(
                "UPDATE shelf_items SET ocr_text = \(sqlNullable(text)) WHERE id = '\(escape(id.uuidString))';"
            )
            if let item = try self.one(id: id) {
                try self.reindexFTS(item)
            }
        }
    }

    /// Sprint 13 / ADR-0013: record the OCR outcome (ok/failed) without text.
    public func setOCRStatus(id: UUID, status: OCRStatus?) async throws {
        try inTransaction {
            try self.exec(
                "UPDATE shelf_items SET ocr_status = \(sqlNullable(status?.rawValue)) WHERE id = '\(escape(id.uuidString))';"
            )
        }
    }

    public func setNote(id: UUID, text: String?) async throws {
        try inTransaction {
            try self.exec(
                "UPDATE shelf_items SET note = \(sqlNullable(text)) WHERE id = '\(escape(id.uuidString))';"
            )
            if let item = try self.one(id: id) {
                try self.reindexFTS(item)
            }
        }
    }

    public func search(_ query: String, limit: Int) async throws -> [ShelfItem] {
        guard let fts = Self.ftsQuery(query) else { return [] }
        return try runQuery(
            """
            SELECT \(columns) FROM shelf_items s
            WHERE s.id IN (
                SELECT item_id FROM shelf_items_fts WHERE shelf_items_fts MATCH ?
            ) AND s.status != 'deleted'
            ORDER BY s.captured_at DESC LIMIT ?;
            """,
            binds: { stmt in stmt.bind(1, fts).bind(2, Int64(max(0, limit))) }
        )
    }

    public func searchExcerpts(_ query: String, limit: Int) async throws -> [SearchResult] {
        guard let fts = Self.ftsQuery(query) else { return [] }
        let stmt = try prepare("""
            SELECT s.id, s.source_url, s.display_name, s.original_name, s.captured_at, s.ingested_at,
                   s.app_name, s.category, s.status, s.ocr_text, s.ocr_status, s.note,
                   snippet(shelf_items_fts, 1, '', '', '…', 12) AS excerpt
            FROM shelf_items_fts f
            JOIN shelf_items s ON s.id = f.item_id
            WHERE shelf_items_fts MATCH ? AND s.status != 'deleted'
            ORDER BY bm25(shelf_items_fts) LIMIT ?;
            """)
        stmt.bind(1, fts)
        stmt.bind(2, Int64(max(0, limit)))
        var results: [SearchResult] = []
        while try stmt.step() {
            results.append(SearchResult(item: decode(stmt), excerpt: stmt.text(12) ?? ""))
        }
        return results
    }

    // MARK: - Internals

    private var columns: String {
        "id, source_url, display_name, original_name, captured_at, ingested_at, app_name, category, status, ocr_text, ocr_status, note"
    }

    private func upsertRow(_ item: ShelfItem) throws {
        let stmt = try prepare("""
            INSERT OR REPLACE INTO shelf_items
            (id, source_url, display_name, original_name, captured_at, ingested_at, app_name, category, status, ocr_text, ocr_status, note)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?);
            """)
        stmt.bind(1, item.id.uuidString)
        stmt.bind(2, item.sourceURL.absoluteString)
        stmt.bind(3, item.displayName)
        stmt.bind(4, item.originalName)
        stmt.bind(5, Self.epochMs(item.capturedAt))
        stmt.bind(6, Self.epochMs(item.ingestedAt))
        stmt.bind(7, item.appName)
        stmt.bind(8, item.category?.rawValue)
        stmt.bind(9, item.status.rawValue)
        stmt.bind(10, item.ocrText)
        stmt.bind(11, item.ocrStatus?.rawValue)
        stmt.bind(12, item.note)
        _ = try stmt.step()
        try reindexFTS(item)
    }

    private func reindexFTS(_ item: ShelfItem) throws {
        let del = try prepare("DELETE FROM shelf_items_fts WHERE item_id = ?;")
        del.bind(1, item.id.uuidString)
        _ = try del.step()

        let content = [item.ocrText, item.displayName, item.appName, item.note]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let ins = try prepare("INSERT INTO shelf_items_fts(item_id, content) VALUES (?, ?);")
        ins.bind(1, item.id.uuidString)
        ins.bind(2, content)
        _ = try ins.step()
    }

    private func one(id: UUID) throws -> ShelfItem? {
        let stmt = try prepare("SELECT \(columns) FROM shelf_items WHERE id = ?;")
        stmt.bind(1, id.uuidString)
        return try stmt.step() ? decode(stmt) : nil
    }

    private func runQuery(_ sql: String, binds: ((Statement) throws -> Void)? = nil) throws -> [ShelfItem] {
        let stmt = try prepare(sql)
        try binds?(stmt)
        var rows: [ShelfItem] = []
        while try stmt.step() { rows.append(decode(stmt)) }
        return rows
    }

    private func inTransaction(_ work: () throws -> Void) throws {
        try exec("BEGIN;")
        do {
            try work()
            try exec("COMMIT;")
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    private func prepare(_ sql: String) throws -> Statement {
        try Statement(db: db, sql: sql)
    }

    private func decode(_ stmt: Statement) -> ShelfItem {
        ShelfItem(
            id: UUID(uuidString: stmt.text(0) ?? "") ?? UUID(),
            sourceURL: URL(string: stmt.text(1) ?? "") ?? URL(fileURLWithPath: "/"),
            displayName: stmt.text(2) ?? "",
            originalName: stmt.text(3),
            capturedAt: Self.date(fromMs: stmt.int64(4)),
            ingestedAt: Self.date(fromMs: stmt.int64(5)),
            appName: stmt.text(6),
            category: stmt.text(7).flatMap { ItemCategory(rawValue: $0) },
            status: ShelfItemStatus(rawValue: stmt.text(8) ?? "") ?? .resting,
            ocrText: stmt.text(9),
            ocrStatus: stmt.text(10).flatMap { OCRStatus(rawValue: $0) },
            note: stmt.text(11)
        )
    }

    // MARK: - SQL helpers

    /// Sanitize user input into a safe FTS5 MATCH expression: quote each whitespace token.
    public static func ftsQuery(_ raw: String) -> String? {
        let cleaned = raw.replacingOccurrences(of: "\"", with: " ")
        let tokens = cleaned.split(whereSeparator: { $0.isWhitespace })
            .map { "\"\($0)\"" }
        let joined = tokens.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }

    public static func epochMs(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    public static func date(fromMs ms: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
    }

    private func escape(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }

    private func sqlNullable(_ text: String?) -> String {
        guard let text else { return "NULL" }
        return "'\(escape(text))'"
    }

    #if DEBUG
    public var databasePathForTesting: String { dbPath }
    #endif
}

// MARK: - Statement wrapper

private final class Statement {
    private let db: OpaquePointer?
    private var stmt: OpaquePointer?

    init(db: OpaquePointer?, sql: String) throws {
        self.db = db
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw SQLiteError.prepare(sqliteErrorMessage(db))
        }
    }

    deinit { sqlite3_finalize(stmt) }

    @discardableResult
    func bind(_ index: Int32, _ text: String?) -> Statement {
        if let text {
            sqlite3_bind_text(stmt, index, text, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
        return self
    }

    @discardableResult
    func bind(_ index: Int32, _ value: Int64) -> Statement {
        sqlite3_bind_int64(stmt, index, value)
        return self
    }

    /// Returns true if a row was produced, false if the statement completed.
    func step() throws -> Bool {
        switch sqlite3_step(stmt) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw SQLiteError.step(sqliteErrorMessage(db))
        }
    }

    func text(_ index: Int32) -> String? {
        guard let raw = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: raw)
    }

    func int64(_ index: Int32) -> Int64 {
        sqlite3_column_int64(stmt, index)
    }
}
