import XCTest
@testable import SnapShelfRuntime
@testable import SnapShelfConfig
@testable import SnapShelfRepo
@testable import SnapShelfService
@testable import SnapShelfTypes

// Sprint 13 / ADR-0013: Settings edits must reach the live ShelfModel.

@MainActor
final class ShelfModelSettingsTests: XCTestCase {

    private actor FakeRepo: ShelfItemRepository {
        private var storage: [UUID: ShelfItem] = [:]
        func load() async throws -> [ShelfItem] { Array(storage.values) }
        func upsert(_ item: ShelfItem) async throws { storage[item.id] = item }
        func upsertAll(_ items: [ShelfItem]) async throws { for item in items { storage[item.id] = item } }
        func delete(id: UUID) async throws { storage[id] = nil }
        func recent(_ limit: Int) async throws -> [ShelfItem] {
            Array(storage.values)
                .sorted { $0.capturedAt > $1.capturedAt }
                .prefix(limit)
                .map { $0 }
        }
        func search(_ query: String, limit: Int) async throws -> [ShelfItem] { [] }
        func searchExcerpts(_ query: String, limit: Int) async throws -> [SearchResult] { [] }
        func setOCR(id: UUID, text: String?) async throws {
            if var item = storage[id] { item.ocrText = text; storage[id] = item }
        }
        func setOCRStatus(id: UUID, status: OCRStatus?) async throws {
            if var item = storage[id] { item.ocrStatus = status; storage[id] = item }
        }
        func setNote(id: UUID, text: String?) async throws {
            if var item = storage[id] { item.note = text; storage[id] = item }
        }
        func find(_ id: UUID) async throws -> ShelfItem? { storage[id] }
    }

    /// Mirrors the real pipeline: ingest persists the item so the repository
    /// reflects status changes written back by the model.
    private actor FakePipeline: IntakePipeline {
        private let repo: FakeRepo
        init(repo: FakeRepo) { self.repo = repo }

        func ingest(url: URL) async throws -> ShelfItem {
            let item = ShelfItem(sourceURL: url, displayName: url.lastPathComponent)
            try await repo.upsert(item)
            return item
        }
    }

    private func makeModel(settings: ShelfSettings = .default) -> (ShelfModel, FakeRepo) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-settings-\(UUID().uuidString)", isDirectory: true)
        let repo = FakeRepo()
        let model = ShelfModel(
            paths: AppPaths.make(home: dir),
            settings: settings,
            repository: repo,
            pipeline: FakePipeline(repo: repo)
        )
        return (model, repo)
    }

    func test_applyShelfSettings_updatesSnapshot() {
        let (model, _) = makeModel(settings: ShelfSettings(hoverSeconds: 5, historyLimit: 50, autoStow: true))

        XCTAssertEqual(model.settings.hoverSeconds, 5)

        model.applyShelfSettings(ShelfSettings(hoverSeconds: 15, historyLimit: 50, autoStow: true))

        XCTAssertEqual(model.settings.hoverSeconds, 15)
    }

    func test_applyShelfSettings_disablingAutoStow_cancelsPendingStow() async throws {
        // Arrange: default 5s auto-stow, ingest one item so a stow gets scheduled.
        let (model, repo) = makeModel()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("settled-\(UUID().uuidString).png")

        await model.ingest(url: fileURL)
        let item = try await repo.find(model.surfaced[0].id)
        XCTAssertEqual(item?.status, .resting)

        // Act: turn auto-stow off.
        model.applyShelfSettings(ShelfSettings(hoverSeconds: 5, historyLimit: 50, autoStow: false))

        // Assert: past the original hover window the item stays resting.
        try await Task.sleep(nanoseconds: 5_500_000_000)
        let after = try await repo.find(model.surfaced[0].id)
        XCTAssertEqual(after?.status, .resting, "auto-stow off must cancel pending stows")
    }

    func test_applyShelfSettings_enablingAutoStow_reschedulesRestingItems() async throws {
        // Arrange: auto-stow off at init; item stays resting indefinitely.
        let (model, repo) = makeModel(
            settings: ShelfSettings(hoverSeconds: 5, historyLimit: 50, autoStow: false)
        )
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("resched-\(UUID().uuidString).png")
        await model.ingest(url: fileURL)

        try await Task.sleep(nanoseconds: 1_200_000_000)
        var item = try await repo.find(model.surfaced[0].id)
        XCTAssertEqual(item?.status, .resting, "with autoStow off nothing schedules a stow")

        // Act: enable auto-stow with a 1s window.
        model.applyShelfSettings(ShelfSettings(hoverSeconds: 1, historyLimit: 50, autoStow: true))

        // Assert: the pre-existing resting item is re-armed and stows.
        try await Task.sleep(nanoseconds: 1_800_000_000)
        item = try await repo.find(model.surfaced[0].id)
        XCTAssertEqual(item?.status, .stowed, "enabling auto-stow must reschedule resting items")
    }
}
