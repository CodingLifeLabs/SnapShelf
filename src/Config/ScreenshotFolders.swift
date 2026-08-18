import Foundation

// Sprint 11 (ADR-0011): resolve the real screenshot folders to watch.
// Order: system screencapture location → ~/Desktop (macOS default save target)
// → ~/Pictures/Screenshots (if present) → app Inbox (always) → user-added folders.

/// Resolves which folders on disk the app should watch for new screenshots.
public protocol ScreenshotFolderSource: Sendable {
    /// Ordered, de-duplicated absolute paths the app will watch.
    func watchedFolders(userFolders: [String]) -> [String]
}

public final class DefaultScreenshotFolderSource: ScreenshotFolderSource {
    private let home: URL
    private let screencaptureLocation: @Sendable () -> String?
    private let fileExists: @Sendable (String) -> Bool

    public init(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        screencaptureLocation: (@Sendable () -> String?)? = nil,
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.home = home
        if let screencaptureLocation {
            self.screencaptureLocation = screencaptureLocation
        } else {
            self.screencaptureLocation = {
                // `defaults read com.apple.screencapture location` — read via an
                // instance's persistent-domain accessor (read-only, never writes).
                UserDefaults.standard.stringFromPersistentDomain("location", domain: "com.apple.screencapture")
            }
        }
        self.fileExists = fileExists
    }

    public func watchedFolders(userFolders: [String]) -> [String] {
        var paths: [String] = []
        // Custom screenshot save location (e.g. set via `defaults write com.apple.screencapture location`).
        if let custom = screencaptureLocation(), !custom.isEmpty, fileExists(custom) {
            paths.append(custom)
        }
        // macOS default save target when no custom location is configured.
        let desktop = home.appendingPathComponent("Desktop", isDirectory: true).path
        if fileExists(desktop) { paths.append(desktop) }
        // Modern default on some configurations.
        let screenshots = home
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent("Screenshots", isDirectory: true).path
        if fileExists(screenshots) { paths.append(screenshots) }
        // User-added folders come last; protected app paths are rejected by the caller.
        paths.append(contentsOf: userFolders)
        return ScreenshotFolders.deduplicated(paths)
    }
}

public enum ScreenshotFolders {
    /// Remove duplicates and near-duplicates (trailing-slash / file-reference variants).
    public static func deduplicated(_ paths: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for path in paths {
            let key = normalized(path)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(key)
        }
        return result
    }

    /// Canonical comparison key for a path.
    public static func normalized(_ path: String) -> String {
        var p = path
        // Strip a file-reference suffix ("/Users/x/Desktop/.file/id=123.45").
        if let range = p.range(of: "/.file/id=", options: .backwards) {
            p = String(p[..<range.lowerBound])
        }
        while p.count > 1 && p.hasSuffix("/") { p.removeLast() }
        return p
    }

    /// True when `candidate` is the given path or nested inside it.
    public static func contains(_ path: String, _ candidate: String) -> Bool {
        let a = normalized(path)
        let b = normalized(candidate)
        guard !a.isEmpty, !b.isEmpty else { return false }
        return b == a || b.hasPrefix(a + "/")
    }

    /// Reject folders owned by the app itself (double-ingest protection, ADR-0011 §5).
    public static func isProtected(_ candidate: String, appPaths: AppPaths) -> Bool {
        let protected = [
            appPaths.inboxDirectory.path,
            appPaths.libraryDirectory.path,
            appPaths.recordingsDirectory.path,
            appPaths.supportDirectory.path
        ]
        return protected.contains { contains($0, candidate) }
    }
}

private extension UserDefaults {
    /// Read a key from another defaults domain without touching the app's suite.
    func stringFromPersistentDomain(_ key: String, domain: String) -> String? {
        persistentDomain(forName: domain)?[key] as? String
    }
}
