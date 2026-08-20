import Foundation
import SnapShelfTypes

// SnapShelfRepo — persistence / data access. Owns SQLite+FTS5 in later sprints;
// Sprint 1 ships a JSON-file implementation behind this protocol.

public protocol ShelfItemRepository: Sendable {
    /// All items, newest capture first.
    func load() async throws -> [ShelfItem]
    /// Insert or replace by id.
    func upsert(_ item: ShelfItem) async throws
    /// Bulk insert or replace.
    func upsertAll(_ items: [ShelfItem]) async throws
    /// Remove by id.
    func delete(id: UUID) async throws
    /// Newest-first slice of length `limit`.
    func recent(_ limit: Int) async throws -> [ShelfItem]
    /// Full-text search for matching items (excluding deleted).
    func search(_ query: String, limit: Int) async throws -> [ShelfItem]
    /// Full-text search returning items with a matched excerpt.
    func searchExcerpts(_ query: String, limit: Int) async throws -> [SearchResult]
    /// Attach OCR text to an item and refresh the search index.
    func setOCR(id: UUID, text: String?) async throws
    /// Record the OCR outcome (ok/failed) — Sprint 13 / ADR-0013.
    func setOCRStatus(id: UUID, status: OCRStatus?) async throws
    /// Attach a user note to an item and refresh the search index.
    func setNote(id: UUID, text: String?) async throws
}
