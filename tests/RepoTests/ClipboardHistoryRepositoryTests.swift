import XCTest
@testable import SnapShelfRepo
@testable import SnapShelfTypes

final class ClipboardHistoryRepositoryTests: XCTestCase {

    private func makeFile() throws -> (URL, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-clip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (dir, dir.appendingPathComponent("history.json", isDirectory: false))
    }

    private func entry(_ seed: Int, data: Data = Data([0x89, 0x50])) -> ClipboardEntry {
        ClipboardEntry(image: data, copiedAt: Date(timeIntervalSince1970: Double(seed)))
    }

    func test_record_keepsNewestFirst() async throws {
        let (_, file) = try makeFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let repo = ClipboardHistoryRepository(storeFile: file)

        await repo.record(entry(1))
        await repo.record(entry(2))

        let all = await repo.all()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.first?.copiedAt, Date(timeIntervalSince1970: 2))
    }

    func test_record_dropsOldestBeyondLimit() async throws {
        let (_, file) = try makeFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let repo = ClipboardHistoryRepository(storeFile: file, limit: 3)

        for seed in 1...5 { await repo.record(entry(seed)) }

        let all = await repo.all()
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all.map { Int($0.copiedAt.timeIntervalSince1970) }, [5, 4, 3])
    }

    func test_persistence_survivesNewInstance() async throws {
        let (_, file) = try makeFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let repo = ClipboardHistoryRepository(storeFile: file)
        await repo.record(entry(1, data: Data(repeating: 7, count: 8)))

        let reopened = ClipboardHistoryRepository(storeFile: file)
        let all = await reopened.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.image, Data(repeating: 7, count: 8))
    }

    func test_remove_and_clear() async throws {
        let (_, file) = try makeFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let repo = ClipboardHistoryRepository(storeFile: file)
        let first = entry(1)
        await repo.record(first)
        await repo.record(entry(2))

        await repo.remove(id: first.id)
        var all = await repo.all()
        XCTAssertEqual(all.count, 1)

        await repo.clear()
        all = await repo.all()
        XCTAssertTrue(all.isEmpty)
    }

    func test_inMemory_onlyWhenNoStoreFile() async throws {
        let repo = ClipboardHistoryRepository()
        await repo.record(entry(1))
        let all = await repo.all()
        XCTAssertEqual(all.count, 1) // no persistence, but usable
    }
}
