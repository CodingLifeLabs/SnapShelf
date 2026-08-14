import Foundation
import AppKit
import SnapShelfTypes

// Sprint 7: lifecycle cleanup. Resting (not pinned/stowed) items older than the
// retention window are moved to the Trash — never hard-deleted — and every
// move is recorded so a single `undo` restores all files.

/// One executed trash move, enough to restore the file afterwards.
public struct CleanupRecord: Sendable, Equatable {
    public let item: ShelfItem
    public let originalURL: URL
    public let trashURL: URL?

    public init(item: ShelfItem, originalURL: URL, trashURL: URL?) {
        self.item = item
        self.originalURL = originalURL
        self.trashURL = trashURL
    }
}

/// Abstracts "move to trash / restore" so tests can run without touching ~/.Trash.
public protocol TrashStore: Sendable {
    /// Moves a file to the trash; returns its trash location when known.
    func trash(_ url: URL) async throws -> URL?
    /// Moves a trashed file back to its original location.
    func restore(from trashURL: URL?, to originalURL: URL) async throws
}

/// Production trash backed by NSWorkspace.recycle (Finder-compatible, undoable).
public struct WorkspaceTrashStore: TrashStore {
    public init() {}

    public func trash(_ url: URL) async throws -> URL? {
        let moved = try await NSWorkspace.shared.recycle([url])
        return moved[url]
    }

    public func restore(from trashURL: URL?, to originalURL: URL) async throws {
        guard let trashURL else {
            throw AutoCleanupError.unknownTrashLocation(originalURL)
        }
        try FileManager.default.createDirectory(
            at: originalURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(at: trashURL, to: originalURL)
    }
}

public enum AutoCleanupError: Error, Equatable {
    case unknownTrashLocation(URL)
}

/// Pure selection policy: which items are eligible for cleanup.
public struct AutoCleanupPolicy: Sendable {
    public let retentionDays: Int
    public let now: Date

    public init(retentionDays: Int = 30, now: Date = Date()) {
        self.retentionDays = max(1, retentionDays)
        self.now = now
    }

    /// Resting items whose capture is older than the retention window.
    /// Pinned and stowed items are never eligible.
    public func eligible(_ items: [ShelfItem]) -> [ShelfItem] {
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 86_400)
        return items.filter { $0.status == .resting && $0.capturedAt < cutoff }
    }
}

/// Executes (and undoes) cleanup passes against a trash store.
public struct AutoCleanupService: Sendable {
    public let policy: AutoCleanupPolicy
    public let trash: any TrashStore

    public init(
        policy: AutoCleanupPolicy = AutoCleanupPolicy(),
        trash: any TrashStore = WorkspaceTrashStore()
    ) {
        self.policy = policy
        self.trash = trash
    }

    /// Trashes every eligible on-disk item; returns records for undo.
    /// Missing files are skipped (already gone).
    @discardableResult
    public func cleanup(_ items: [ShelfItem]) async throws -> [CleanupRecord] {
        var records: [CleanupRecord] = []
        for item in policy.eligible(items)
            where FileManager.default.fileExists(atPath: item.sourceURL.path) {
            let trashURL = try await trash.trash(item.sourceURL)
            records.append(CleanupRecord(item: item, originalURL: item.sourceURL, trashURL: trashURL))
        }
        return records
    }

    /// Restores every file moved by a cleanup pass, in reverse order.
    public func undo(_ records: [CleanupRecord]) async throws {
        for record in records.reversed() {
            try await trash.restore(from: record.trashURL, to: record.originalURL)
        }
    }
}
