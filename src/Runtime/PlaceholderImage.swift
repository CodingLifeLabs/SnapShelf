import Foundation
import AppKit
import CoreGraphics

/// Generates placeholder PNG screenshots for the "Simulate Capture" action (and EVAL).
public enum PlaceholderImage {
    public enum Error: Swift.Error {
        case encodingFailed
    }

    /// Accent-tinted PNG of the given pixel size.
    public static func pngData(width: Int, height: Int) throws -> Data {
        let w = max(1, width)
        let h = max(1, height)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw Error.encodingFailed }

        // SnapShelf accent indigo (#6E56CF)
        ctx.setFillColor(red: 0.43, green: 0.34, blue: 0.81, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // subtle shelf hairline across the middle
        ctx.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18)
        ctx.fill(CGRect(x: 0, y: h / 2, width: w, height: 2))

        guard let cgImage = ctx.makeImage() else { throw Error.encodingFailed }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw Error.encodingFailed }
        return png
    }
}
