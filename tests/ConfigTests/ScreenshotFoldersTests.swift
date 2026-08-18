import XCTest
@testable import SnapShelfConfig

// Sprint 11 (ADR-0011): screenshot folder resolution tests.

final class ScreenshotFoldersTests: XCTestCase {
    private var home: URL!
    private var existing: Set<String>!

    override func setUp() {
        super.setUp()
        home = URL(fileURLWithPath: "/Users/tester", isDirectory: true)
        existing = ["/Users/tester/Desktop"]
    }

    private func makeSource(screencaptureLocation: String? = nil) -> DefaultScreenshotFolderSource {
        DefaultScreenshotFolderSource(
            home: home,
            screencaptureLocation: { screencaptureLocation },
            fileExists: { [existing] path in existing.contains(path) }
        )
    }

    func testCustomScreencaptureLocationTakesPriority() {
        existing = ["/Users/tester/Desktop", "/Users/tester/Caps"]
        let source = makeSource(screencaptureLocation: "/Users/tester/Caps")
        XCTAssertEqual(
            source.watchedFolders(userFolders: []),
            ["/Users/tester/Caps", "/Users/tester/Desktop"]
        )
    }

    func testMissingCustomLocationIsSkipped() {
        existing = ["/Users/tester/Desktop"]
        let source = makeSource(screencaptureLocation: "/Users/tester/nope")
        XCTAssertEqual(source.watchedFolders(userFolders: []), ["/Users/tester/Desktop"])
    }

    // MARK: - Resolution

    func testDesktopIsWatchedByDefault() {
        let source = makeSource()
        let folders = source.watchedFolders(userFolders: [])
        XCTAssertEqual(folders, ["/Users/tester/Desktop"])
    }

    func testMissingDesktopIsSkipped() {
        existing = []
        let source = makeSource()
        XCTAssertTrue(source.watchedFolders(userFolders: []).isEmpty)
    }

    func testPicturesScreenshotsAddedWhenPresent() {
        existing = ["/Users/tester/Desktop", "/Users/tester/Pictures/Screenshots"]
        let source = makeSource()
        XCTAssertEqual(
            source.watchedFolders(userFolders: []),
            ["/Users/tester/Desktop", "/Users/tester/Pictures/Screenshots"]
        )
    }

    func testUserFoldersAppendedAndDeduplicated() {
        existing = ["/Users/tester/Desktop", "/Users/tester/Shots"]
        let source = makeSource()
        let folders = source.watchedFolders(userFolders: ["/Users/tester/Shots", "/Users/tester/Desktop", "/Users/tester/Extra"])
        XCTAssertEqual(folders, ["/Users/tester/Desktop", "/Users/tester/Shots", "/Users/tester/Extra"])
    }

    // MARK: - Normalization helpers

    func testDeduplicatedRemovesTrailingSlashes() {
        XCTAssertEqual(
            ScreenshotFolders.deduplicated(["/a/b/", "/a/b", "/c"]),
            ["/a/b", "/c"]
        )
    }

    func testDeduplicatedStripsFileReferenceSuffix() {
        XCTAssertEqual(
            ScreenshotFolders.deduplicated(["/Users/x/Desktop", "/Users/x/Desktop/.file/id=123.45"]),
            ["/Users/x/Desktop"]
        )
    }

    func testContainsDetectsNestedPaths() {
        XCTAssertTrue(ScreenshotFolders.contains("/Users/x", "/Users/x/Desktop"))
        XCTAssertTrue(ScreenshotFolders.contains("/Users/x/Desktop", "/Users/x/Desktop"))
        XCTAssertFalse(ScreenshotFolders.contains("/Users/x/Desktop", "/Users/x/Desktopz"))
        XCTAssertFalse(ScreenshotFolders.contains("/Users/x/Desktop", "/Users/x"))
    }

    // MARK: - Protected paths

    func testAppOwnedPathsAreProtected() {
        let paths = AppPaths.make(home: URL(fileURLWithPath: "/Users/tester", isDirectory: true))
        XCTAssertTrue(ScreenshotFolders.isProtected("/Users/tester/Library/Application Support/SnapShelf/Inbox", appPaths: paths))
        XCTAssertTrue(ScreenshotFolders.isProtected("/Users/tester/Library/Application Support/SnapShelf/Inbox/nested", appPaths: paths))
        XCTAssertTrue(ScreenshotFolders.isProtected("/Users/tester/Library/Application Support/SnapShelf", appPaths: paths))
        XCTAssertFalse(ScreenshotFolders.isProtected("/Users/tester/Desktop", appPaths: paths))
    }

    // MARK: - Settings persistence

    func testWatchedFoldersPersistRoundTrip() {
        let suiteName = "watched-folders-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AppSettingsStore(defaults: defaults)

        var settings = AppSettings.default
        settings.watchedFolders = ["/Users/tester/Shots"]
        store.save(settings)

        let loaded = store.load()
        XCTAssertEqual(loaded.watchedFolders, ["/Users/tester/Shots"])
    }

    func testDefaultWatchedFoldersEmpty() {
        XCTAssertEqual(AppSettings.default.watchedFolders, [])
    }
}
