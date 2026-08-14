import Foundation
import SnapShelfTypes
import SnapShelfRepo
import SnapShelfService

// Sprint 7: duplicate-resolution runtime. Scans shelf items for near-duplicate
// screenshots (pHash), and on user approval trashes the redundant copies while
// keeping the newest capture of each group.

@MainActor
@Observable
public final class DuplicatesModel {
    public private(set) var groups: [DuplicateGroup] = []
    public private(set) var isScanning = false
    public private(set) var statusMessage: String = ""

    private let deduplicator: Deduplicator
    private let trash: any TrashStore
    private let repository: any ShelfItemRepository

    public init(
        repository: any ShelfItemRepository,
        deduplicator: Deduplicator = Deduplicator(),
        trash: any TrashStore = WorkspaceTrashStore()
    ) {
        self.repository = repository
        self.deduplicator = deduplicator
        self.trash = trash
    }

    /// (Re)scan the given items off the main actor; hashing is CPU-bound.
    public func scan(items: [ShelfItem]) async {
        isScanning = true
        defer { isScanning = false }
        let deduplicator = deduplicator
        let found = await Task.detached(priority: .utility) {
            deduplicator.duplicateGroups(among: items)
        }.value
        groups = found
        statusMessage = found.isEmpty
            ? "No duplicates found."
            : "Found \(found.count) duplicate group(s)."
    }

    /// User-approved resolution: keep the keeper, trash the duplicates.
    public func resolve(_ group: DuplicateGroup) async {
        do {
            for duplicate in group.duplicates
                where FileManager.default.fileExists(atPath: duplicate.sourceURL.path) {
                _ = try await trash.trash(duplicate.sourceURL)
                var deleted = duplicate
                deleted.status = .deleted
                try await repository.upsert(deleted)
            }
            groups.removeAll { $0.id == group.id }
            statusMessage = "Kept “\(group.keeper.displayName)”; trashed \(group.duplicates.count) duplicate(s)."
        } catch {
            statusMessage = "Resolve failed: \(error)"
        }
    }

    /// Drop a group from the list without touching any files.
    public func skip(_ group: DuplicateGroup) {
        groups.removeAll { $0.id == group.id }
    }
}
