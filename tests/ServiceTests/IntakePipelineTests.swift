import XCTest
@testable import SnapShelfService
@testable import SnapShelfRepo
@testable import SnapShelfTypes

final class IntakeSupportTests: XCTestCase {

    // MARK: - beautify

    func test_beautify_stripsMacOSScreenshotTimeBlock() {
        // Arrange / Act / Assert
        XCTAssertEqual(
            IntakeSupport.beautify("Screenshot 2026-08-14 at 10.22.03.png"),
            "Screenshot 2026-08-14.png"
        )
    }

    func test_beautify_handlesSingleDigitHour() {
        XCTAssertEqual(
            IntakeSupport.beautify("Screenshot 2026-08-14 at 9.05.11.png"),
            "Screenshot 2026-08-14.png"
        )
    }

    func test_beautify_unchangedWhenPatternAbsent() {
        XCTAssertEqual(IntakeSupport.beautify("Supabase Login Error.png"), "Supabase Login Error.png")
        XCTAssertEqual(IntakeSupport.beautify("CleanShot X.png"), "CleanShot X.png")
    }

    // MARK: - creationDate

    func test_creationDate_returnsNilForMissingFile() {
        let url = URL(fileURLWithPath: "/does/not/exist/\(UUID().uuidString).png")
        XCTAssertNil(IntakeSupport.creationDate(of: url))
    }

    func test_creationDate_returnsDateForExistingFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-intake-\(UUID().uuidString).png")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let date = IntakeSupport.creationDate(of: url)
        XCTAssertNotNil(date)
    }
}

final class DefaultIntakePipelineTests: XCTestCase {

    private actor FakeRepository: ShelfItemRepository {
        private var storage: [UUID: ShelfItem] = [:]

        func load() async throws -> [ShelfItem] { Array(storage.values) }
        func upsert(_ item: ShelfItem) async throws { storage[item.id] = item }
        func upsertAll(_ items: [ShelfItem]) async throws { for item in items { storage[item.id] = item } }
        func delete(id: UUID) async throws { storage[id] = nil }
        func recent(_ limit: Int) async throws -> [ShelfItem] {
            Array(storage.values).prefix(limit).map { $0 }
        }
        func snapshot() -> [ShelfItem] { Array(storage.values) }
    }

    func test_ingest_persistsItemWithBeautifiedName() async throws {
        // Arrange
        let repo = FakeRepository()
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let pipeline = DefaultIntakePipeline(repository: repo, clock: { fixedDate })
        let url = URL(fileURLWithPath: "/tmp/Screenshot 2026-08-14 at 10.22.03.png")

        // Act
        let item = try await pipeline.ingest(url: url)
        let stored = await repo.snapshot()

        // Assert
        XCTAssertEqual(item.displayName, "Screenshot 2026-08-14.png")
        XCTAssertEqual(item.originalName, "Screenshot 2026-08-14 at 10.22.03.png")
        XCTAssertEqual(item.capturedAt, fixedDate) // missing file -> falls back to clock
        XCTAssertEqual(item.ingestedAt, fixedDate)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, item.id)
    }

    func test_ingest_usesFileCreationDateWhenAvailable() async throws {
        let repo = FakeRepository()
        let clockDate = Date(timeIntervalSince1970: 9_999)
        let pipeline = DefaultIntakePipeline(repository: repo, clock: { clockDate })

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-intake-\(UUID().uuidString).png")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let item = try await pipeline.ingest(url: url)

        // capturedAt should come from the file, NOT the clock fallback
        XCTAssertNotEqual(item.capturedAt, clockDate)
        XCTAssertEqual(item.ingestedAt, clockDate)
    }
}
