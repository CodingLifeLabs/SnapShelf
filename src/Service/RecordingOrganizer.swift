import Foundation

// Sprint 8: screen recordings follow the same intake as screenshots but need
// a separate folder root and file-type filter. Reuses the Organizer's rule
// engine idea, but for .mov/.mp4 files under ~/SnapShelf Library/Recordings.

public struct RecordingOrganizer: @unchecked Sendable {
    public let recordingsRoot: URL
    // FileManager is documented thread-safe; only used for local moves.
    private let fileManager: FileManager

    /// File extensions treated as recordings.
    public static let recordingExtensions: Set<String> = ["mov", "mp4", "m4v"]

    public init(recordingsRoot: URL, fileManager: FileManager = .default) {
        self.recordingsRoot = recordingsRoot
        self.fileManager = fileManager
    }

    /// Whether a file is a screen recording by extension.
    public func isRecording(_ url: URL) -> Bool {
        Self.recordingExtensions.contains(url.pathExtension.lowercased())
    }

    /// Date-bucketed subpath for a recording: "2026/08".
    public static func monthBucket(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 0
        let month = String(format: "%02d", comps.month ?? 0)
        return "\(year)/\(month)"
    }

    /// Move a recording into its month bucket under the root. Best-effort:
    /// returns the destination when moved, nil when the file is missing or
    /// not a recording (original is never deleted on failure).
    @discardableResult
    public func organize(_ url: URL, capturedAt: Date = Date()) -> URL? {
        guard isRecording(url), fileManager.fileExists(atPath: url.path) else { return nil }
        let destDir = recordingsRoot
            .appendingPathComponent(Self.monthBucket(for: capturedAt), isDirectory: true)
        do {
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)
            let dest = uniqueDestination(in: destDir, filename: url.lastPathComponent)
            try fileManager.moveItem(at: url, to: dest)
            return dest
        } catch {
            return nil
        }
    }

    /// All organized recordings, newest-first, bounded.
    public func list(limit: Int = 200) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: recordingsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var results: [(url: URL, date: Date)] = []
        for case let url as URL in enumerator where isRecording(url) {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            results.append((url, date))
        }
        return Array(
            results.sorted { $0.date > $1.date }.prefix(limit).map(\.url)
        )
    }

    private func uniqueDestination(in dir: URL, filename: String) -> URL {
        let base = dir.appendingPathComponent(filename)
        if !fileManager.fileExists(atPath: base.path) { return base }
        let stem = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        return dir.appendingPathComponent("\(stem)-\(UUID().uuidString.prefix(6)).\(ext)")
    }
}
