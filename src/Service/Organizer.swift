import Foundation
import SnapShelfTypes

// Sprint 5: Smart Folder organizer. Moves captured files into categorized subpaths
// UNDER the app-owned library root (TCC-free). Detects source app/category from OCR
// when missing, applies the rule engine, and moves the file atomically (same volume).
// Never throws away the item: if the move fails, detected metadata is still returned
// and the file is left in place.

public struct Organizer: Sendable {
    public let libraryRoot: URL
    public let engine: FolderRuleEngine
    public let detector: SourceDetector

    public init(
        libraryRoot: URL,
        engine: FolderRuleEngine = FolderRuleEngine(rules: FolderRuleEngine.defaultRules),
        detector: SourceDetector = SourceDetector()
    ) {
        self.libraryRoot = libraryRoot
        self.engine = engine
        self.detector = detector
    }

    /// Detect source if missing, then move into the matched subpath. Best-effort:
    /// returns the (possibly metadata-enriched) item even if the move fails.
    @discardableResult
    public func organize(_ item: ShelfItem) -> ShelfItem {
        let fm = FileManager.default
        var updated = item
        if updated.appName == nil {
            updated.appName = detector.detectApp(ocrText: updated.ocrText, filename: updated.displayName)
        }
        if updated.category == nil {
            updated.category = detector.detectCategory(app: updated.appName, ocrText: updated.ocrText)
        }

        guard let subpath = engine.target(for: updated),
              fm.fileExists(atPath: item.sourceURL.path) else {
            return updated
        }

        let destDir = libraryRoot.appendingPathComponent(subpath, isDirectory: true)
        do {
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            let dest = uniqueDestination(in: destDir, filename: item.sourceURL.lastPathComponent, fileManager: fm)
            try fm.moveItem(at: item.sourceURL, to: dest)
            updated.sourceURL = dest
        } catch {
            // Move failed (e.g. cross-volume edge case). Keep metadata, leave file in place.
        }
        return updated
    }

    /// Avoid clobbering an existing file by appending a short unique suffix.
    private func uniqueDestination(in dir: URL, filename: String, fileManager fm: FileManager) -> URL {
        let base = dir.appendingPathComponent(filename)
        if !fm.fileExists(atPath: base.path) { return base }
        let stem = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let suffix = String(UUID().uuidString.prefix(6))
        let name = ext.isEmpty ? "\(stem) \(suffix)" : "\(stem) \(suffix).\(ext)"
        return dir.appendingPathComponent(name)
    }
}
