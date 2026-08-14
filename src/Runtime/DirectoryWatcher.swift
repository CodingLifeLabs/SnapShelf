import Foundation
import Darwin

// SnapShelfRuntime — app lifecycle, watchers, panels, status bar, permissions.

public protocol ScreenshotWatcher: Sendable {
    func start() async throws
    func stop() async
}

public enum WatcherError: Error, Equatable {
    case openFailed(String)
}

/// Watches a directory for new image files via a kernel dispatch source.
/// Pre-existing files are seeded silently; only newly-added files fire the handler.
public actor DirectoryWatcher: ScreenshotWatcher {
    public typealias NewFileHandler = @Sendable (URL) -> Void

    private let directory: URL
    private let fileExtensions: Set<String>
    private let handler: NewFileHandler
    private var knownFiles: Set<String> = []
    private var source: DispatchSourceFileSystemObject?
    private var fd: CInt = -1
    private let queue = DispatchQueue(label: "app.snapshelf.DirectoryWatcher")

    public init(
        directory: URL,
        fileExtensions: Set<String> = ["png", "jpg", "jpeg", "heic"],
        handler: @escaping NewFileHandler
    ) {
        self.directory = directory
        self.fileExtensions = fileExtensions
        self.handler = handler
    }

    public func start() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        knownFiles = Set(filteredNames(currentFileNames()))

        fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { throw WatcherError.openFailed(directory.path) }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: .write, queue: queue
        )
        let dir = directory
        src.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.rescan(directory: dir) }
        }
        let openedFd = fd
        src.setCancelHandler {
            close(openedFd)
        }
        source = src
        src.resume()
    }

    public func stop() async {
        source?.cancel()
        source = nil
        fd = -1
    }

    /// Pure diff used by rescan; also a direct test hook.
    /// Returns newly-seen (matching) file names and updates `knownFiles`.
    public func newFiles(from listing: [String]) -> [String] {
        let candidates = Set(filteredNames(listing))
        let added = candidates.subtracting(knownFiles)
        knownFiles = candidates
        return Array(added).sorted()
    }

    private func rescan(directory: URL) {
        let added = newFiles(from: currentFileNames())
        for name in added {
            handler(directory.appendingPathComponent(name))
        }
    }

    private func currentFileNames() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    private func filteredNames(_ names: [String]) -> [String] {
        names.filter { fileExtensions.contains(fileExtension(of: $0)) }
    }

    private func fileExtension(of name: String) -> String {
        String(name.split(separator: ".").last ?? "").lowercased()
    }
}
