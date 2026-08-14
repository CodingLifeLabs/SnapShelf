import XCTest
import AppKit
@testable import SnapShelfRuntime
@testable import SnapShelfRepo
@testable import SnapShelfService
@testable import SnapShelfTypes

final class ClipboardHistoryModelTests: XCTestCase {

    private func makePNG(width: Int, height: Int) throws -> Data {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw NSError(domain: "fixture", code: 1) }
        ctx.setFillColor(red: 0.4, green: 0.5, blue: 0.9, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = try XCTUnwrap(ctx.makeImage())
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    // MARK: - downscaling

    @MainActor
    func test_downscaledPNG_boundsLargeImages() throws {
        let large = try makePNG(width: 1200, height: 800)

        let stored = ClipboardHistoryModel.downscaledPNG(from: large, maxEdge: 512)

        XCTAssertNotNil(stored)
        let image = try XCTUnwrap(NSImage(data: stored!))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 513, "stored edge is bounded")
    }

    @MainActor
    func test_downscaledPNG_keepsSmallImagesUntouchedSize() throws {
        let small = try makePNG(width: 64, height: 32)

        let stored = ClipboardHistoryModel.downscaledPNG(from: small, maxEdge: 512)

        let image = try XCTUnwrap(NSImage(data: stored!))
        XCTAssertEqual(image.size.width, 64, accuracy: 1)
        XCTAssertEqual(image.size.height, 32, accuracy: 1)
    }

    @MainActor
    func test_downscaledPNG_rejectsNonImageBytes() {
        XCTAssertNil(ClipboardHistoryModel.downscaledPNG(from: Data([1, 2, 3]), maxEdge: 512))
    }

    // MARK: - history flow

    @MainActor
    func test_recordAndRefresh_flowThroughRepository() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-model-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let history = ClipboardHistoryRepository(
            storeFile: dir.appendingPathComponent("history.json", isDirectory: false)
        )
        let model = ClipboardHistoryModel(history: history)

        await history.record(ClipboardEntry(image: try makePNG(width: 8, height: 8)))
        await model.refresh()

        XCTAssertEqual(model.entries.count, 1)
        XCTAssertFalse(model.isRunning, "start() not called yet")

        await model.clear()
        XCTAssertTrue(model.entries.isEmpty)
    }

    @MainActor
    func test_copyBack_putsImageOnPasteboard() async throws {
        let png = try makePNG(width: 8, height: 8)
        let pb = NSPasteboard(name: .init("snapshelf-clipmodel-\(UUID().uuidString)"))
        let service = ClipboardService()
        let entry = ClipboardEntry(image: png)

        let ok = service.copyPNGData(entry.image, pasteboard: pb)

        XCTAssertTrue(ok)
        XCTAssertNotNil(pb.data(forType: .tiff))
    }
}
