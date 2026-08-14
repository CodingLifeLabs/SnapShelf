import Foundation
import SnapShelfTypes

/// JSON-file backed repository. Idempotent and atomic; safe to instantiate repeatedly.
/// Replaced by SQLiteShelfRepository (FTS5) in Sprint 3 behind the same protocol.
public actor FileShelfRepository: ShelfItemRepository {
    private let storeFile: URL
    private let fileManager: FileManager
    private var byID: [UUID: ShelfItem] = [:]
    private var loaded = false

    public init(storeFile: URL, fileManager: FileManager = .default) {
        self.storeFile = storeFile
        self.fileManager = fileManager
    }

    #if DEBUG
    /// Nonisolated accessor for tests (URL is Sendable; `storeFile` is a let).
    nonisolated public var storeFileForTesting: URL { storeFile }
    #endif

    // MARK: - ShelfItemRepository

    public func load() async throws -> [ShelfItem] {
        try ensureLoaded()
        return sortedDescending()
    }

    public func upsert(_ item: ShelfItem) async throws {
        try ensureLoaded()
        byID[item.id] = item
        try persist()
    }

    public func upsertAll(_ items: [ShelfItem]) async throws {
        try ensureLoaded()
        for item in items {
            byID[item.id] = item
        }
        try persist()
    }

    public func delete(id: UUID) async throws {
        try ensureLoaded()
        byID[id] = nil
        try persist()
    }

    public func recent(_ limit: Int) async throws -> [ShelfItem] {
        try ensureLoaded()
        return Array(sortedDescending().prefix(max(0, limit)))
    }

    // MARK: - Internals

    private func ensureLoaded() throws {
        guard !loaded else { return }
        loaded = true
        guard fileManager.fileExists(atPath: storeFile.path),
              let data = try? Data(contentsOf: storeFile) else { return }
        let decoded = (try? JSONDecoder().decode([ShelfItem].self, from: data)) ?? []
        for item in decoded {
            byID[item.id] = item
        }
    }

    private func sortedDescending() -> [ShelfItem] {
        byID.values.sorted { lhs, rhs in
            if lhs.capturedAt == rhs.capturedAt { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.capturedAt > rhs.capturedAt
        }
    }

    private func persist() throws {
        let array = sortedDescending()
        let data = try JSONEncoder().encode(array)
        let dir = storeFile.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: storeFile, options: .atomic)
    }
}
