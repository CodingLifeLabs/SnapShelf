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
}
