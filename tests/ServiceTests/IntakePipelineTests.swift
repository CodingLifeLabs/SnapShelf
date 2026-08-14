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
        func search(_ query: String, limit: Int) async throws -> [ShelfItem] {
            let q = query.lowercased()
            guard !q.isEmpty else { return [] }
            let matches = storage.values.filter {
                $0.displayName.lowercased().contains(q)
                    || ($0.ocrText?.lowercased().contains(q) ?? false)
            }
            return Array(matches.prefix(max(0, limit)))
        }
        func searchExcerpts(_ query: String, limit: Int) async throws -> [SearchResult] {
            try await search(query, limit: limit)
                .map { SearchResult(item: $0, excerpt: $0.ocrText ?? $0.displayName) }
        }
        func setOCR(id: UUID, text: String?) async throws {
            if var item = storage[id] { item.ocrText = text; storage[id] = item }
        }
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

    // MARK: - OCR integration

    private actor FakeOCR: OCRService {
        private let text: String
        init(_ text: String) { self.text = text }
        func recognize(_ url: URL) async throws -> String { text }
    }

    private actor FakeAI: AIService {
        private let name: String
        init(_ name: String) { self.name = name }
        func rename(_ item: ShelfItem) async throws -> String { name }
        func summarize(_ text: String) async throws -> String { "summary" }
    }

    func test_ingest_withAIRename_updatesDisplayName() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-intake-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = dir.appendingPathComponent("index.json", isDirectory: false)
        let repo = FileShelfRepository(storeFile: store)
        let pipeline = DefaultIntakePipeline(
            repository: repo,
            aiService: FakeAI("Supabase Login Error"),
            renameEnabled: true,
            clock: { Date(timeIntervalSince1970: 1) }
        )

        let item = try await pipeline.ingest(url: URL(fileURLWithPath: "/tmp/Screenshot 2026-08-14.png"))

        XCTAssertEqual(item.displayName, "Supabase Login Error")
        let loaded = try await repo.load()
        XCTAssertEqual(loaded.first?.displayName, "Supabase Login Error")
    }

    func test_ingest_renameDisabled_keepsBeautifiedName() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-intake-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = dir.appendingPathComponent("index.json", isDirectory: false)
        let repo = FileShelfRepository(storeFile: store)
        let pipeline = DefaultIntakePipeline(
            repository: repo,
            aiService: FakeAI("Ignored Name"),
            renameEnabled: false,
            clock: { Date(timeIntervalSince1970: 1) }
        )

        let item = try await pipeline.ingest(url: URL(fileURLWithPath: "/tmp/Screenshot 2026-08-14 at 10.22.03.png"))

        XCTAssertEqual(item.displayName, "Screenshot 2026-08-14.png")
    }

    func test_ingest_withOCR_indexesTextForSearch() async throws {
        // Arrange: real FileShelfRepository + fake OCR service
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-intake-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = dir.appendingPathComponent("index.json", isDirectory: false)
        let repo = FileShelfRepository(storeFile: store)
        let ocr = FakeOCR("Supabase auth error 401")
        let pipeline = DefaultIntakePipeline(
            repository: repo, ocrService: ocr, clock: { Date(timeIntervalSince1970: 1) }
        )

        // Act
        _ = try await pipeline.ingest(url: URL(fileURLWithPath: "/tmp/shot.png"))

        // Assert: OCR text was indexed and is searchable
        let results = try await repo.searchExcerpts("Supabase", limit: 10)
        XCTAssertEqual(results.count, 1)
    }
}
