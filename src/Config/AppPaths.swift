import Foundation

// SnapShelfConfig — paths, constants, settings schemas.

public enum ConfigError: Error, Equatable {
    case cannotCreateDirectory(String)
}

/// Resolved on-disk locations used by the app.
/// Default inbox lives under Application Support (TCC-free) so the core capture→shelf
/// loop works without a permission prompt. The real screenshot folder is wired in a later sprint.
public struct AppPaths: Sendable, Equatable {
    public let supportDirectory: URL
    public let inboxDirectory: URL
    public let libraryDirectory: URL
    public let storeFile: URL
    public let databaseFile: URL
    public let clipboardHistoryFile: URL
    public let recordingsDirectory: URL
    public let privacyLogFile: URL

    public init(
        supportDirectory: URL,
        inboxDirectory: URL,
        libraryDirectory: URL,
        storeFile: URL,
        databaseFile: URL,
        clipboardHistoryFile: URL,
        recordingsDirectory: URL,
        privacyLogFile: URL
    ) {
        self.supportDirectory = supportDirectory
        self.inboxDirectory = inboxDirectory
        self.libraryDirectory = libraryDirectory
        self.storeFile = storeFile
        self.databaseFile = databaseFile
        self.clipboardHistoryFile = clipboardHistoryFile
        self.recordingsDirectory = recordingsDirectory
        self.privacyLogFile = privacyLogFile
    }

    /// Derive all paths from a home directory.
    public static func make(home: URL) -> AppPaths {
        let support = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("SnapShelf", isDirectory: true)
        return AppPaths(
            supportDirectory: support,
            inboxDirectory: support.appendingPathComponent("Inbox", isDirectory: true),
            libraryDirectory: support.appendingPathComponent("Library", isDirectory: true),
            storeFile: support.appendingPathComponent("index.json", isDirectory: false),
            databaseFile: support.appendingPathComponent("index.sqlite", isDirectory: false),
            clipboardHistoryFile: support.appendingPathComponent("clipboard-history.json", isDirectory: false),
            recordingsDirectory: support.appendingPathComponent("Recordings", isDirectory: true),
            privacyLogFile: support.appendingPathComponent("privacy-log.jsonl", isDirectory: false)
        )
    }

    /// Paths for the current user.
    public static func current() -> AppPaths {
        make(home: FileManager.default.homeDirectoryForCurrentUser)
    }

    /// Create support/inbox/library directories if missing.
    public func ensureExists() throws {
        let fm = FileManager.default
        for dir in [supportDirectory, inboxDirectory, libraryDirectory] {
            try createIfNeeded(dir, fileManager: fm)
        }
    }

    private func createIfNeeded(_ url: URL, fileManager fm: FileManager) throws {
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue { return }
        do {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw ConfigError.cannotCreateDirectory(url.path)
        }
    }
}
