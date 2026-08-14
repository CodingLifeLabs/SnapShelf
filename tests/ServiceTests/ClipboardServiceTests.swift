import XCTest
import AppKit
@testable import SnapShelfService

final class ClipboardServiceTests: XCTestCase {

    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: .init("snapshelf-test-\(UUID().uuidString)"))
    }

    func test_copyFile_writesFileURLToPasteboard() throws {
        // Arrange
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-clip-\(UUID().uuidString).png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let pb = makePasteboard()
        let service = ClipboardService()

        // Act
        let ok = service.copyFile(at: url, pasteboard: pb)

        // Assert
        XCTAssertTrue(ok)
        let written = pb.string(forType: .fileURL)
        XCTAssertEqual(written, url.absoluteString)
    }

    func test_copyFile_clearsPriorContents() throws {
        let url = try writeTempPng()
        defer { try? FileManager.default.removeItem(at: url) }
        let pb = makePasteboard()
        pb.setString("stale", forType: .string)

        service_copyFile(at: url, on: pb)

        XCTAssertNil(pb.string(forType: .string))
        XCTAssertEqual(pb.string(forType: .fileURL), url.absoluteString)
    }

    func test_copyImage_writesImageWhenReadable() throws {
        // Use the runtime PlaceholderImage generation indirectly: write a real PNG.
        let url = try writeTempPng()
        defer { try? FileManager.default.removeItem(at: url) }
        let pb = makePasteboard()

        let ok = ClipboardService().copyImage(at: url, pasteboard: pb)

        XCTAssertTrue(ok)
        // NSImage writes TIFF (not PNG) to the pasteboard.
        XCTAssertNotNil(pb.data(forType: .tiff))
    }

    func test_copyImage_returnsFalseForMissingFile() {
        let pb = makePasteboard()
        let ok = ClipboardService().copyImage(at: URL(fileURLWithPath: "/no/such/file.png"), pasteboard: pb)
        XCTAssertFalse(ok)
    }

    // MARK: - helpers

    private enum FixtureError: Error { case encode }

    private func writeTempPng() throws -> URL {
        // Generate a real, readable 4x4 indigo PNG (8 header bytes alone are not decodable).
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FixtureError.encode }
        ctx.setFillColor(red: 0.43, green: 0.34, blue: 0.81, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        guard let cgImage = ctx.makeImage(),
              let rep = NSBitmapImageRep(cgImage: cgImage) as NSBitmapImageRep?,
              let data = rep.representation(using: .png, properties: [:])
        else { throw FixtureError.encode }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-clip-\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    private func service_copyFile(at url: URL, on pb: NSPasteboard) {
        ClipboardService().copyFile(at: url, pasteboard: pb)
    }
}
