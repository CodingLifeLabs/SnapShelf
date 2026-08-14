import XCTest
import CoreGraphics
import AppKit
@testable import SnapShelfService

final class VisionOCRServiceTests: XCTestCase {

    private func writePlainPng() throws -> URL {
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FixtureError.encode }
        ctx.setFillColor(red: 0.4, green: 0.3, blue: 0.8, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        guard let image = ctx.makeImage(),
              let rep = NSBitmapImageRep(cgImage: image) as NSBitmapImageRep?,
              let data = rep.representation(using: .png, properties: [:])
        else { throw FixtureError.encode }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-ocr-\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    private enum FixtureError: Error { case encode }

    func test_recognize_missingFileThrows() async {
        let service = VisionOCRService()
        let url = URL(fileURLWithPath: "/no/such/\(UUID().uuidString).png")
        do {
            _ = try await service.recognize(url)
            XCTFail("expected throw for missing file")
        } catch {
            // expected
        }
    }

    func test_recognize_plainImageReturnsEmptyWithoutThrowing() async throws {
        let url = try writePlainPng()
        defer { try? FileManager.default.removeItem(at: url) }

        let text = try await VisionOCRService().recognize(url)

        XCTAssertEqual(text, "")
    }
}
