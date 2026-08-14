import AppKit

// Sprint 2: shelf interactions — copy file/image to the pasteboard.
// Accepts an explicit pasteboard so it is unit-testable with a private pasteboard.

public struct ClipboardService: Sendable {
    public init() {}

    /// Copy the file reference (URL) to the pasteboard — drop into Finder, attach to mail, etc.
    @discardableResult
    public func copyFile(at url: URL, pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        return pasteboard.writeObjects([url as NSURL])
    }

    /// Copy the image bytes (so it can be pasted into image wells, Slack, notes).
    @discardableResult
    public func copyImage(at url: URL, pasteboard: NSPasteboard = .general) -> Bool {
        guard let image = NSImage(contentsOf: url) else { return false }
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }

    /// Copy raw PNG bytes back to the pasteboard (Smart Clipboard history entries).
    @discardableResult
    public func copyPNGData(_ data: Data, pasteboard: NSPasteboard = .general) -> Bool {
        guard let image = NSImage(data: data) else { return false }
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }
}
