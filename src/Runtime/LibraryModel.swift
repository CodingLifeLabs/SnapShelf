import Foundation

// Sprint 6: scans the app-owned Library root for Smart Folder subfolders (created by Organizer).

@MainActor
@Observable
public final class LibraryModel {
    public let libraryRoot: URL
    public private(set) var folders: [String] = []

    public init(libraryRoot: URL) {
        self.libraryRoot = libraryRoot
    }

    /// Refresh the list of immediate subdirectories under the library root.
    public func refresh() {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: libraryRoot.path) else {
            folders = []
            return
        }
        folders = entries
            .filter { name in
                var isDir: ObjCBool = false
                let path = libraryRoot.appendingPathComponent(name).path
                return fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
            }
            .sorted()
    }
}
