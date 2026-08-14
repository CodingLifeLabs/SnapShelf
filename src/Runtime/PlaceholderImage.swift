import Foundation
import AppKit
import CoreGraphics

/// Generates placeholder PNG screenshots for the "Simulate Capture" action (and EVAL).
/// Draws a neutral mock-screenshot (window chrome + faux content lines) so the shelf
/// preview reads as captured content rather than a solid color swatch.
public enum PlaceholderImage {
    public enum Error: Swift.Error {
        case encodingFailed
    }

    public static func pngData(width: Int, height: Int) throws -> Data {
        let w = CGFloat(max(1, width))
        let h = CGFloat(max(1, height))
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0,
            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw Error.encodingFailed }

        // CoreGraphics origin is bottom-left.
        // 1. Page background (neutral light gray).
        fill(ctx, CGRect(x: 0, y: 0, width: w, height: h), CGColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1))

        // 2. White card.
        let inset = max(8, min(w, h) * 0.03)
        let card = CGRect(x: inset, y: inset, width: w - inset * 2, height: h - inset * 2)
        fillRounded(ctx, card, radius: 12, color: CGColor(red: 1, green: 1, blue: 1, alpha: 1))

        // 3. Title bar pill + traffic-light dots.
        let titleH = max(22, h * 0.09)
        let titleInset: CGFloat = 6
        let title = CGRect(
            x: card.minX + titleInset,
            y: card.maxY - titleH - titleInset,
            width: card.width - titleInset * 2,
            height: titleH
        )
        fillRounded(ctx, title, radius: 6, color: CGColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1))

        let dotR = max(3, titleH * 0.13)
        var dotX = title.minX + dotR + 8
        let dotY = title.midY
        for color in [
            CGColor(red: 0.96, green: 0.39, blue: 0.40, alpha: 1), // red
            CGColor(red: 0.95, green: 0.77, blue: 0.27, alpha: 1), // yellow
            CGColor(red: 0.42, green: 0.78, blue: 0.36, alpha: 1)  // green
        ] {
            fillEllipse(ctx,
                        CGRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2),
                        color)
            dotX += dotR * 2 + 7
        }

        // 4. Faux content lines (gray, varying widths) — suggests text/UI, no brand color.
        let lineColor = CGColor(red: 0.82, green: 0.83, blue: 0.86, alpha: 1)
        let lineH = max(8, h * 0.035)
        let leftX = card.minX + max(16, w * 0.04)
        let rightEdge = card.maxX - max(16, w * 0.04)
        let widths: [CGFloat] = [0.95, 0.7, 0.85, 0.55, 0.6, 0.75]
        var y = title.minY - max(14, h * 0.06)
        for frac in widths {
            guard y - lineH > card.minY + inset else { break }
            let lw = (rightEdge - leftX) * frac
            fillRounded(ctx, CGRect(x: leftX, y: y - lineH, width: lw, height: lineH),
                        radius: lineH / 2, color: lineColor)
            y -= lineH + max(8, h * 0.03)
        }

        guard let cgImage = ctx.makeImage() else { throw Error.encodingFailed }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw Error.encodingFailed }
        return png
    }

    // MARK: - Drawing helpers

    private static func fill(_ ctx: CGContext, _ rect: CGRect, _ color: CGColor) {
        ctx.setFillColor(color)
        ctx.fill(rect)
    }

    private static func fillRounded(_ ctx: CGContext, _ rect: CGRect, radius: CGFloat, color: CGColor) {
        let r = min(radius, min(rect.width, rect.height) / 2)
        ctx.setFillColor(color)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.fillPath()
    }

    private static func fillEllipse(_ ctx: CGContext, _ rect: CGRect, _ color: CGColor) {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: rect)
    }
}
