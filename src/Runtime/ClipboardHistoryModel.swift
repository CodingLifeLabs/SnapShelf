import Foundation
import AppKit
import SnapShelfTypes
import SnapShelfRepo
import SnapShelfService

// Sprint 7: Smart Clipboard runtime. Polls the general pasteboard for image
// copies, stores downscaled PNG entries in the local history repository, and
// copies entries back on demand. Polling (not events) keeps this local-only
// and avoids the accessibility permission.

@MainActor
@Observable
public final class ClipboardHistoryModel {
    public private(set) var entries: [ClipboardEntry] = []
    public private(set) var isRunning = false

    /// Longest stored edge so the history file stays bounded.
    private static let maxStoredEdge = 512.0

    private let history: ClipboardHistoryRepository
    private let clipboard: ClipboardService
    private var timer: Timer?
    private var lastChangeCount: Int = 0

    public init(
        history: ClipboardHistoryRepository,
        clipboard: ClipboardService = ClipboardService()
    ) {
        self.history = history
        self.clipboard = clipboard
    }

    // MARK: - Lifecycle

    public func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        isRunning = true
        Task { await refresh() }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    // MARK: - Capture

    /// Records the current pasteboard image (if any). Called on every change.
    public func poll() async {
        let pasteboard = NSPasteboard.general
        let change = pasteboard.changeCount
        guard change != lastChangeCount else { return }
        lastChangeCount = change

        guard pasteboard.types?.contains(.png) == true,
              let data = pasteboard.data(forType: .png),
              let stored = Self.downscaledPNG(from: data, maxEdge: Self.maxStoredEdge) else { return }
        await history.record(ClipboardEntry(image: stored))
        await refresh()
    }

    /// Newest-first history snapshot.
    public func refresh() async {
        entries = await history.all()
    }

    /// Put an entry's image back on the pasteboard.
    @discardableResult
    public func copyBack(_ entry: ClipboardEntry) -> Bool {
        clipboard.copyPNGData(entry.image)
    }

    public func remove(_ entry: ClipboardEntry) async {
        await history.remove(id: entry.id)
        await refresh()
    }

    public func clear() async {
        await history.clear()
        await refresh()
    }

    // MARK: - Internals

    /// Re-encode pasteboard PNG bytes bounded to `maxEdge` (keeps storage small).
    static func downscaledPNG(from data: Data, maxEdge: Double) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        let edge = max(image.size.width, image.size.height)
        let ratio = edge > maxEdge ? maxEdge / edge : 1.0
        let target = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(target.width.rounded()), pixelsHigh: Int(target.height.rounded()),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        )
        guard let rep else { return nil }
        rep.size = target
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.current = context
        image.draw(
            in: NSRect(origin: .zero, size: target),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        context.flushGraphics()
        return rep.representation(using: .png, properties: [:])
    }
}
