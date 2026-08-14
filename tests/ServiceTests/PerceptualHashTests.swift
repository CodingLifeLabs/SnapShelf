import XCTest
import AppKit
@testable import SnapShelfService

final class PerceptualHashTests: XCTestCase {

    /// Horizontal gradient (0...1 gray), optionally brightness-offset.
    private func gradientPNG(width: Int, height: Int, offset: Double = 0) -> Data {
        renderPNG(width: width, height: height) { x, _ in
            min(1.0, max(0.0, Double(x) / Double(max(1, width - 1)) + offset))
        }
    }

    /// 8-pixel checkerboard (high-frequency structure).
    private func checkerboardPNG(width: Int, height: Int) -> Data {
        renderPNG(width: width, height: height) { x, y in
            ((x / 8) + (y / 8)) % 2 == 0 ? 0.0 : 1.0
        }
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

    private func writeFile(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("phash-\(name)-\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    /// 4 horizontal bands (0, 0.33, 0.66, 1) — quantized content survives
    /// rescaling without the median-threshold noise a smooth ramp suffers.
    private func bandsPNG(width: Int, height: Int) -> Data {
        renderPNG(width: width, height: height) { x, _ in
            Double(x * 4 / max(1, width)) * 0.33
        }
    }

    func test_identicalBytes_hashEqual() throws {
        let hasher = PerceptualHash()
        let data = bandsPNG(width: 64, height: 64)
        let a = try writeFile(data, name: "a")
        let b = try writeFile(data, name: "b")
        defer {
            try? FileManager.default.removeItem(at: a)
            try? FileManager.default.removeItem(at: b)
        }

        XCTAssertEqual(PerceptualHash.hammingDistance(hasher.hash(of: a)!, hasher.hash(of: b)!), 0)
    }

    func test_rescaledContent_staysWithinDuplicateBar() throws {
        let hasher = PerceptualHash()
        let small = try writeFile(bandsPNG(width: 64, height: 64), name: "small")
        let large = try writeFile(bandsPNG(width: 256, height: 256), name: "large")
        defer {
            try? FileManager.default.removeItem(at: small)
            try? FileManager.default.removeItem(at: large)
        }

        let distance = PerceptualHash.hammingDistance(hasher.hash(of: small)!, hasher.hash(of: large)!)
        XCTAssertLessThanOrEqual(distance, 3, "rescaled duplicate must stay within the 95% bar")
    }

    func test_structurallyDifferentImage_isDistant() throws {
        // pHash is brightness-invariant by design (solid black == solid white),
        // so distance must be measured across STRUCTURE: gradient vs checkerboard.
        let hasher = PerceptualHash()
        let smooth = try writeFile(gradientPNG(width: 100, height: 100), name: "smooth")
        let busy = try writeFile(checkerboardPNG(width: 100, height: 100), name: "busy")
        defer {
            try? FileManager.default.removeItem(at: smooth)
            try? FileManager.default.removeItem(at: busy)
        }

        let distance = PerceptualHash.hammingDistance(hasher.hash(of: smooth)!, hasher.hash(of: busy)!)
        XCTAssertGreaterThan(distance, 8, "structurally different images must not be near-identical")
    }

    func test_missingFile_returnsNil() {
        XCTAssertNil(PerceptualHash().hash(of: URL(fileURLWithPath: "/no/such/image.png")))
    }

    func test_hammingAndSimilarity_math() {
        XCTAssertEqual(PerceptualHash.hammingDistance(0, 0), 0)
        XCTAssertEqual(PerceptualHash.hammingDistance(0, 0b1111), 4)
        XCTAssertEqual(PerceptualHash.similarity(0, 0), 1.0)
        // 4/64 bits differ -> 93.75% similarity (below the 95% duplicate bar)
        XCTAssertEqual(PerceptualHash.similarity(0, 0b1111), 0.9375, accuracy: 0.0001)
    }

    func test_similarityThreshold_threeBitsCovers95Percent() {
        // The default duplicate bar (distance <= 3) corresponds to >= 95.3% similarity,
        // while 4 differing bits already falls below 95%.
        let threeBits = UInt64(0b111)
        XCTAssertEqual(PerceptualHash.similarity(0, threeBits), 61.0 / 64.0, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(PerceptualHash.similarity(0, threeBits), 0.95)
        XCTAssertLessThan(PerceptualHash.similarity(0, UInt64(0b1111)), 0.95)
    }
}
