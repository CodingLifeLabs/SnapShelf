import XCTest
import AppKit
@testable import SnapShelfService
@testable import SnapShelfTypes

final class DeduplicatorTests: XCTestCase {

    /// Solid-color PNG of the given white value.
    private func solidPNG(_ white: Double, size: Int = 64) -> Data {
        renderPNG(width: size, height: size) { _, _ in white }
    }

    /// 8-pixel checkerboard — high-frequency structure, far from any solid.
    private func checkerboardPNG(size: Int = 64) -> Data {
        renderPNG(width: size, height: size) { x, y in ((x / 8) + (y / 8)) % 2 == 0 ? 0.0 : 1.0 }
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

    private var dir: URL {
        let d = FileManager.default.temporaryDirectory
            .appendingPathComponent("dedup-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    private func writeItem(_ data: Data, name: String, captured: TimeInterval, in dir: URL) -> ShelfItem {
        let url = dir.appendingPathComponent(name)
        try? data.write(to: url)
        return ShelfItem(
            sourceURL: url,
            displayName: name,
            capturedAt: Date(timeIntervalSince1970: captured)
        )
    }

    func test_similarImages_groupWithNewestAsKeeper() throws {
        let dir = dir
        defer { try? FileManager.default.removeItem(at: dir) }

        // Same solid color at different sizes -> identical visual content.
        let old = writeItem(solidPNG(0.5, size: 64), name: "old.png", captured: 100, in: dir)
        let newest = writeItem(solidPNG(0.5, size: 200), name: "new.png", captured: 300, in: dir)

        let groups = Deduplicator().duplicateGroups(among: [old, newest])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].keeper.id, newest.id, "newest capture is the keeper")
        XCTAssertEqual(groups[0].duplicates.map(\.id), [old.id])
    }

    func test_differentImages_areNotGrouped() throws {
        let dir = dir
        defer { try? FileManager.default.removeItem(at: dir) }

        // pHash is brightness-invariant (solid black == solid white), so use
        // structural difference: solid vs checkerboard.
        let flat = writeItem(solidPNG(0.5), name: "flat.png", captured: 100, in: dir)
        let busy = writeItem(checkerboardPNG(), name: "busy.png", captured: 200, in: dir)

        let groups = Deduplicator().duplicateGroups(among: [flat, busy])

        XCTAssertTrue(groups.isEmpty)
    }

    func test_threeWayCluster_becomesOneGroup() throws {
        let dir = dir
        defer { try? FileManager.default.removeItem(at: dir) }

        let a = writeItem(solidPNG(0.25, size: 60), name: "a.png", captured: 100, in: dir)
        let b = writeItem(solidPNG(0.25, size: 120), name: "b.png", captured: 200, in: dir)
        let c = writeItem(solidPNG(0.25, size: 240), name: "c.png", captured: 300, in: dir)

        let groups = Deduplicator().duplicateGroups(among: [a, b, c])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].keeper.id, c.id)
        XCTAssertEqual(groups[0].duplicates.count, 2)
    }

    func test_missingFiles_areIgnored() {
        let ghost = ShelfItem(
            sourceURL: URL(fileURLWithPath: "/no/such/ghost.png"),
            displayName: "ghost.png"
        )
        XCTAssertTrue(Deduplicator().duplicateGroups(among: [ghost]).isEmpty)
    }
}
