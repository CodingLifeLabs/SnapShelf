import XCTest
@testable import SnapShelfRuntime

@MainActor
final class LibraryModelTests: XCTestCase {

    func test_refresh_listsSubfoldersOnly() throws {
        // Arrange
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-lib-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // create two subfolders + a stray file
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Supabase"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Errors"), withIntermediateDirectories: true)
        try Data([1]).write(to: root.appendingPathComponent("note.txt"))

        // Act
        let model = LibraryModel(libraryRoot: root)
        model.refresh()

        // Assert
        XCTAssertEqual(model.folders, ["Errors", "Supabase"]) // sorted, file excluded
    }

    func test_refresh_emptyWhenRootMissing() {
        let model = LibraryModel(libraryRoot: URL(fileURLWithPath: "/no/such/dir-\(UUID().uuidString)"))
        model.refresh()
        XCTAssertTrue(model.folders.isEmpty)
    }
}
