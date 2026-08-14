import XCTest
@testable import SnapShelfConfig

final class AppPathsTests: XCTestCase {

    // MARK: - Structure

    func test_make_derivesExpectedSubpaths() {
        // Arrange
        let home = URL(fileURLWithPath: "/Users/test")
        // Act
        let paths = AppPaths.make(home: home)
        // Assert
        XCTAssertEqual(paths.supportDirectory.path, "/Users/test/Library/Application Support/SnapShelf")
        XCTAssertEqual(paths.inboxDirectory.path, "/Users/test/Library/Application Support/SnapShelf/Inbox")
        XCTAssertEqual(paths.libraryDirectory.path, "/Users/test/Library/Application Support/SnapShelf/Library")
        XCTAssertEqual(paths.storeFile.path, "/Users/test/Library/Application Support/SnapShelf/index.json")
    }

    func test_make_isConsistentWithExplicitInit() {
        let home = URL(fileURLWithPath: "/h")
        let derived = AppPaths.make(home: home)
        let explicit = AppPaths(
            supportDirectory: derived.supportDirectory,
            inboxDirectory: derived.inboxDirectory,
            libraryDirectory: derived.libraryDirectory,
            storeFile: derived.storeFile
        )
        XCTAssertEqual(derived, explicit)
    }

    // MARK: - ensureExists

    func test_ensureExists_createsMissingDirectories() throws {
        // Arrange
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-config-\(UUID().uuidString)", isDirectory: true)
        let paths = AppPaths(
            supportDirectory: tmp,
            inboxDirectory: tmp.appendingPathComponent("Inbox", isDirectory: true),
            libraryDirectory: tmp.appendingPathComponent("Library", isDirectory: true),
            storeFile: tmp.appendingPathComponent("index.json", isDirectory: false)
        )
        defer { try? FileManager.default.removeItem(at: tmp) }

        // Act
        try paths.ensureExists()

        // Assert
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: paths.inboxDirectory.path))
        XCTAssertTrue(fm.fileExists(atPath: paths.libraryDirectory.path))
    }

    func test_ensureExists_isIdempotent() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-config-\(UUID().uuidString)", isDirectory: true)
        let paths = AppPaths(
            supportDirectory: tmp,
            inboxDirectory: tmp.appendingPathComponent("Inbox", isDirectory: true),
            libraryDirectory: tmp.appendingPathComponent("Library", isDirectory: true),
            storeFile: tmp.appendingPathComponent("index.json", isDirectory: false)
        )
        defer { try? FileManager.default.removeItem(at: tmp) }

        try paths.ensureExists()
        XCTAssertNoThrow(try paths.ensureExists()) // second call must not throw
    }
}

final class ShelfSettingsTests: XCTestCase {
    func test_defaults() {
        let s = ShelfSettings.default
        XCTAssertEqual(s.hoverSeconds, 5)
        XCTAssertEqual(s.historyLimit, 50)
        XCTAssertTrue(s.autoStow)
    }

    func test_codable_roundTrip() throws {
        let s = ShelfSettings(hoverSeconds: 12, historyLimit: 100, autoStow: false)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(ShelfSettings.self, from: data)
        XCTAssertEqual(back, s)
    }
}
