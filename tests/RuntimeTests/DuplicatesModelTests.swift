import XCTest
import AppKit
@testable import SnapShelfRuntime
@testable import SnapShelfRepo
@testable import SnapShelfService
@testable import SnapShelfTypes

final class DuplicatesModelTests: XCTestCase {

    private actor FakeRepo: ShelfItemRepository {
        private var storage: [UUID: ShelfItem] = [:]
        func load() async throws -> [ShelfItem] { Array(storage.values) }
        func upsert(_ item: ShelfItem) async throws { storage[item.id] = item }
        func upsertAll(_ items: [ShelfItem]) async throws { for item in items { storage[item.id] = item } }
        func delete(id: UUID) async throws { storage[id] = nil }
        func recent(_ limit: Int) async throws -> [ShelfItem] { Array(storage.values.prefix(limit)) }
        func search(_ query: String, limit: Int) async throws -> [ShelfItem] { [] }
        func searchExcerpts(_ query: String, limit: Int) async throws -> [SearchResult] { [] }
        func setOCRStatus(id: UUID, status: OCRStatus?) async throws { }
        func setOCR(id: UUID, text: String?) async throws {}
        func setNote(id: UUID, text: String?) async throws {}
        func find(_ id: UUID) async throws -> ShelfItem? { storage[id] }
    }

    private func solidPNG(_ white: Double, size: Int = 64) -> Data {
        renderPNG(width: size, height: size) { _, _ in white }
    }

    /// Renders a synthetic PNG via CGContext (per-pixel white value in 0...1).
    /// NSBitmapImageRep.setColor on a grayscale rep silently no-ops, so CG is required.
    private func renderPNG(width: Int, height: Int, white: (Int, Int) -> Double) -> Data {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        for y in 0..<height {
            for x in 0..<width {
                let value = CGFloat(white(x, y))
                ctx.setFillColor(red: value, green: value, blue: value, alpha: 1)
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        return rep.representation(using: .png, properties: [:])!
    }

    @MainActor
    func test_scan_findsDuplicateGroup() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dup-model-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let aURL = dir.appendingPathComponent("a.png")
        try solidPNG(0.5, size: 64).write(to: aURL)
        let bURL = dir.appendingPathComponent("b.png")
        try solidPNG(0.5, size: 128).write(to: bURL)

        let model = DuplicatesModel(repository: FakeRepo())
        let a = ShelfItem(sourceURL: aURL, displayName: "a.png", capturedAt: Date(timeIntervalSince1970: 100))
        let b = ShelfItem(sourceURL: bURL, displayName: "b.png", capturedAt: Date(timeIntervalSince1970: 200))

        await model.scan(items: [a, b])

        XCTAssertEqual(model.groups.count, 1)
        XCTAssertEqual(model.groups[0].keeper.id, b.id)
    }

    @MainActor
    func test_skip_removesGroupWithoutTouchingFiles() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dup-skip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let aURL = dir.appendingPathComponent("a.png")
        try solidPNG(0.5).write(to: aURL)
        let bURL = dir.appendingPathComponent("b.png")
        try solidPNG(0.5, size: 128).write(to: bURL)

        let model = DuplicatesModel(repository: FakeRepo())
        await model.scan(items: [
            ShelfItem(sourceURL: aURL, displayName: "a.png"),
            ShelfItem(sourceURL: bURL, displayName: "b.png", capturedAt: Date(timeIntervalSince1970: 50))
        ])
        guard let group = model.groups.first else { return XCTFail("expected a group") }

        model.skip(group)

        XCTAssertTrue(model.groups.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: aURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: bURL.path))
    }
}
