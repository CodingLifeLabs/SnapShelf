import Foundation
import SnapShelfTypes
import SnapShelfRepo
import SnapShelfService

// Sprint 7: cleanup runtime. Runs the retention pass against the shelf items,
// marks cleaned items as deleted in the repository, and keeps the last pass's
// records so the user can undo (restore files + statuses).

@MainActor
@Observable
public final class CleanupModel {
    public private(set) var statusMessage: String = ""
    public private(set) var canUndo = false
    public private(set) var cleanedCount = 0

    private let repository: any ShelfItemRepository
    private let service: AutoCleanupService
    private var lastRecords: [CleanupRecord] = []

    public init(
        repository: any ShelfItemRepository,
        service: AutoCleanupService = AutoCleanupService()
    ) {
        self.repository = repository
        self.service = service
    }

    /// Trashes overdue resting items (files + status), remembering the pass for undo.
    public func runCleanup(items: [ShelfItem]) async {
        do {
            let records = try await service.cleanup(items)
            lastRecords = records
            cleanedCount = records.count
            canUndo = !records.isEmpty
            for record in records {
                var deleted = record.item
                deleted.status = .deleted
                try await repository.upsert(deleted)
            }
            statusMessage = records.isEmpty
                ? "Nothing to clean up."
                : "Moved \(records.count) item(s) to Trash. Undo available."
        } catch {
            statusMessage = "Cleanup failed: \(error)"
        }
    }

    /// Restores the last pass's files and flips statuses back.
    public func undoLast() async {
        guard !lastRecords.isEmpty else { return }
        do {
            try await service.undo(lastRecords)
            for record in lastRecords {
                var restored = record.item
                restored.status = .resting
                try await repository.upsert(restored)
            }
            statusMessage = "Restored \(lastRecords.count) item(s) from Trash."
            lastRecords = []
            canUndo = false
        } catch {
            statusMessage = "Undo failed: \(error)"
        }
    }
}
