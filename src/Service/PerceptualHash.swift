import AppKit

// Sprint 7: perceptual image hashing (pHash) for duplicate detection.
// Pipeline: downscale to 32x32 grayscale -> 8x8 DCT-II coefficients ->
// median threshold -> 64-bit hash. Visually similar screenshots land within
// a few bits of each other regardless of filename or size.

public struct PerceptualHash: Sendable {
    /// Downscale target before the DCT.
    private static let sampleSize = 32
    /// DCT block side (8x8 = 64 coefficients = 64 hash bits).
    private static let dctSize = 8

    public init() {}

    /// Hash of the image at `url`, or nil if it cannot be decoded.
    public func hash(of url: URL) -> UInt64? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return hash(of: image)
    }

    /// Hash of an in-memory image.
    public func hash(of image: NSImage) -> UInt64? {
        guard let gray = Self.grayscaleSamples(from: image) else { return nil }
        let coefficients = Self.dctCoefficients(of: gray)
        return Self.bits(from: coefficients)
    }

    // MARK: - Grayscale

    /// Downscale-draws the image into a 32x32 RGBA CGContext and returns
    /// luminance samples. CGContext is used because NSImage.draw into an
    /// NSGraphicsContext(bitmapImageRep:) silently no-ops for some sources.
    private static func grayscaleSamples(from image: NSImage) -> [Double]? {
        let n = sampleSize
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              let context = CGContext(
                  data: nil,
                  width: n, height: n,
                  bitsPerComponent: 8, bytesPerRow: n * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: n, height: n))
        guard let buffer = context.data else { return nil }

        let pixels = buffer.bindMemory(to: UInt8.self, capacity: n * n * 4)
        var luminance = [Double](repeating: 0, count: n * n)
        for index in 0..<(n * n) {
            let offset = index * 4
            let r = Double(pixels[offset])
            let g = Double(pixels[offset + 1])
            let b = Double(pixels[offset + 2])
            luminance[index] = 0.299 * r + 0.587 * g + 0.114 * b
        }
        return luminance
    }

    // MARK: - DCT-II

    /// 8x8 DCT-II coefficients of the 32x32 sample grid, in row-major order.
    private static func dctCoefficients(of samples: [Double]) -> [Double] {
        let n = sampleSize
        let m = dctSize
        // cosTable[u][x] = cos((2x + 1) * u * pi / (2n))
        var cosTable = [[Double]](repeating: [Double](repeating: 0, count: n), count: m)
        for u in 0..<m {
            for x in 0..<n {
                cosTable[u][x] = cos((2.0 * Double(x) + 1.0) * Double(u) * .pi / (2.0 * Double(n)))
            }
        }

        // Row pass: rows -> frequency domain over u.
        var rows = [[Double]](repeating: [Double](repeating: 0, count: n), count: m)
        for u in 0..<m {
            for y in 0..<n {
                var sum = 0.0
                for x in 0..<n {
                    sum += samples[y * n + x] * cosTable[u][x]
                }
                rows[u][y] = sum
            }
        }

        // Column pass: -> frequency domain over v.
        var output = [Double](repeating: 0, count: m * m)
        for u in 0..<m {
            for v in 0..<m {
                var sum = 0.0
                for y in 0..<n {
                    sum += rows[u][y] * cosTable[v][y]
                }
                output[u * m + v] = sum
            }
        }
        return output
    }

    /// Median-threshold the coefficients into 64 bits.
    private static func bits(from coefficients: [Double]) -> UInt64 {
        let sorted = coefficients.sorted()
        let median = sorted[sorted.count / 2]
        var hash: UInt64 = 0
        for (index, value) in coefficients.enumerated() where value > median {
            hash |= 1 << UInt64(index)
        }
        return hash
    }
}

// MARK: - Distance

public extension PerceptualHash {
    /// Number of differing bits between two hashes (0...64).
    static func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }

    /// Similarity in 0...1; 1 = identical hashes.
    static func similarity(_ lhs: UInt64, _ rhs: UInt64) -> Double {
        1.0 - Double(hammingDistance(lhs, rhs)) / 64.0
    }
}
