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

    // MARK: - settle policy (Sprint 13 / ADR-0013)

    func test_isStable_requiresTwoSamples() {
        XCTAssertFalse(IntakeSupport.isStable(sampling: []))
        XCTAssertFalse(IntakeSupport.isStable(sampling: [100]))
    }

    func test_isStable_trueWhenLastTwoSamplesAgree() {
        XCTAssertTrue(IntakeSupport.isStable(sampling: [0, 100, 100]))
        XCTAssertTrue(IntakeSupport.isStable(sampling: [100, 100]))
    }

    func test_isStable_falseWhileFileStillGrowing() {
        XCTAssertFalse(IntakeSupport.isStable(sampling: [0, 100, 300, 700]))
        XCTAssertFalse(IntakeSupport.isStable(sampling: [100, 300]))
    }
}

/// Sprint 13 / ADR-0013: OCR service that always fails, to exercise the
/// failure-visibility path (row persisted + ocrStatus = .failed).
private struct FailingOCR: OCRService {
    struct RecognizeError: Error {}
    func recognize(_ url: URL) async throws -> String { throw RecognizeError() }
}

/// Records the file sizes observed between settle probes.
private actor SizeProbes {
    private var sizes: [Int] = []
    func record(_ size: Int) { sizes.append(size) }
    func all() -> [Int] { sizes }
}

private extension DefaultIntakePipelineTests {
    /// Fresh `stat` (resourceValues caches and would mask growth).
    static func freshSize(of url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? Int) ?? 0
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
        func setOCRStatus(id: UUID, status: OCRStatus?) async throws { }
        func setOCR(id: UUID, text: String?) async throws {
            if var item = storage[id] { item.ocrText = text; storage[id] = item }
        }
        func setNote(id: UUID, text: String?) async throws {
            if var item = storage[id] { item.note = text; storage[id] = item }
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

    // MARK: - OCR failure visibility (Sprint 13 / ADR-0013)

    func test_ingest_ocrFailure_stillPersistsItemAndMarksFailed() async throws {
        // Arrange
        let repo = FakeRepository()
        let pipeline = DefaultIntakePipeline(
            repository: repo,
            ocrService: FailingOCR(),
            clock: { Date(timeIntervalSince1970: 1) },
            settleAttempts: 2,
            settleIntervalNanos: 1
        )

        // Act
        let item = try await pipeline.ingest(url: URL(fileURLWithPath: "/tmp/broken.png"))
        let stored = await repo.snapshot()

        // Assert: the capture is never lost, and the failure is visible.
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(item.ocrStatus, .failed)
        XCTAssertNil(item.ocrText)
        XCTAssertEqual(stored.first?.ocrStatus, .failed)
    }

    func test_ingest_ocrSuccess_marksOk() async throws {
        // Arrange
        let repo = FakeRepository()
        let pipeline = DefaultIntakePipeline(
            repository: repo,
            ocrService: FakeOCR("recognized text"),
            clock: { Date(timeIntervalSince1970: 1) },
            settleAttempts: 2,
            settleIntervalNanos: 1
        )

        // Act
        let item = try await pipeline.ingest(url: URL(fileURLWithPath: "/tmp/shot.png"))

        // Assert
        XCTAssertEqual(item.ocrStatus, .ok)
        XCTAssertEqual(item.ocrText, "recognized text")
    }

    func test_ingest_waitsForFileToSettleBeforeOCR() async throws {
        // Arrange: the injected sleep doubles as the "writer" — it appends to
        // the file on every probe, so the size strictly increases between
        // samples and the file can never look settled early (deterministic,
        // no real-time race with an external writer task).
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-settle-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("growing.png")
        try Data(repeating: 0, count: 10).write(to: url)

        let probes = SizeProbes()
        let growingSleep: @Sendable (UInt64) async -> Void = { interval in
            try? await Task.sleep(nanoseconds: interval)
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(repeating: 1, count: 10))
            }
            await probes.record(Self.freshSize(of: url))
        }

        let repo = FakeRepository()
        let pipeline = DefaultIntakePipeline(
            repository: repo,
            clock: { Date(timeIntervalSince1970: 1) },
            settleAttempts: 5,
            settleIntervalNanos: 1,
            sleep: growingSleep
        )

        // Act: ingest must still complete once attempts are exhausted.
        _ = try await pipeline.ingest(url: url)

        // Assert: settle kept probing while the file kept changing.
        let sampled = await probes.all()
        XCTAssertEqual(sampled.count, 4, "a still-growing file is probed on every attempt")
        XCTAssertEqual(sampled, Array(sampled.sorted()), "size strictly increases across probes")
    }
}
