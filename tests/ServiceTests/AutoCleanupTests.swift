import XCTest
@testable import SnapShelfService
@testable import SnapShelfTypes

final class AutoCleanupTests: XCTestCase {

    /// Local fake trash: moves files into a temp directory instead of ~/.Trash.
    private struct FakeTrashStore: TrashStore {
        let trashDir: URL

        func trash(_ url: URL) async throws -> URL? {
            let dest = trashDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: dest)
            return dest
        }

        func restore(from trashURL: URL?, to originalURL: URL) async throws {
            guard let trashURL else { throw AutoCleanupError.unknownTrashLocation(originalURL) }
            try FileManager.default.moveItem(at: trashURL, to: originalURL)
        }
    }

    private func makeEnv(retentionDays: Int = 30) throws -> (service: AutoCleanupService, dir: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cleanup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let trashDir = dir.appendingPathComponent("Trash", isDirectory: true)
        try FileManager.default.createDirectory(at: trashDir, withIntermediateDirectories: true)
        let now = Date(timeIntervalSince1970: 1_000_000)
        let service = AutoCleanupService(
            policy: AutoCleanupPolicy(retentionDays: retentionDays, now: now),
            trash: FakeTrashStore(trashDir: trashDir)
        )
        return (service, dir)
    }

    private func writeFile(_ name: String, in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data([0x89, 0x50]).write(to: url)
        return url
    }

    private func item(
        _ name: String, url: URL, ageDays: Double, status: ShelfItemStatus = .resting
    ) -> ShelfItem {
        let now = Date(timeIntervalSince1970: 1_000_000)
        return ShelfItem(
            sourceURL: url,
            displayName: name,
            capturedAt: now.addingTimeInterval(-ageDays * 86_400),
            status: status
        )
    }

    // MARK: - Policy

    func test_eligible_selectsOldRestingItemsOnly() throws {
        let (service, dir) = try makeEnv()
        defer { try? FileManager.default.removeItem(at: dir) }

        let old = item("old.png", url: try writeFile("old.png", in: dir), ageDays: 40)
        let fresh = item("fresh.png", url: try writeFile("fresh.png", in: dir), ageDays: 2)
        let pinned = item("pinned.png", url: try writeFile("pinned.png", in: dir), ageDays: 90, status: .pinned)
        let stowed = item("stowed.png", url: try writeFile("stowed.png", in: dir), ageDays: 90, status: .stowed)

        let eligible = service.policy.eligible([old, fresh, pinned, stowed])
        XCTAssertEqual(eligible.map(\.id), [old.id])
    }

    // MARK: - Cleanup + undo

    func test_cleanup_trashesEligibleFilesAndUndoRestores() async throws {
        let (service, dir) = try makeEnv()
        defer { try? FileManager.default.removeItem(at: dir) }
        let oldURL = try writeFile("old.png", in: dir)
        let freshURL = try writeFile("fresh.png", in: dir)
        let old = item("old.png", url: oldURL, ageDays: 40)
        let fresh = item("fresh.png", url: freshURL, ageDays: 2)

        let records = try await service.cleanup([old, fresh])

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].originalURL, oldURL)
        XCTAssertNotNil(records[0].trashURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path), "eligible file trashed")
        XCTAssertTrue(FileManager.default.fileExists(atPath: freshURL.path), "fresh file untouched")

        try await service.undo(records)

        XCTAssertTrue(FileManager.default.fileExists(atPath: oldURL.path), "undo restores the file")
        XCTAssertFalse(FileManager.default.fileExists(atPath: records[0].trashURL!.path), "trash copy gone")
    }

    func test_cleanup_skipsMissingFiles() async throws {
        let (service, dir) = try makeEnv()
        defer { try? FileManager.default.removeItem(at: dir) }
        let ghost = item("ghost.png", url: dir.appendingPathComponent("ghost.png"), ageDays: 90)

        let records = try await service.cleanup([ghost])

        XCTAssertTrue(records.isEmpty)
    }

    func test_workspaceTrashStore_isAvailable() {
        // Construction only — actual recycle needs a real user Trash (covered in EVAL).
        _ = WorkspaceTrashStore()
    }
}
