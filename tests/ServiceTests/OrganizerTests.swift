import XCTest
@testable import SnapShelfService
@testable import SnapShelfTypes

final class OrganizerTests: XCTestCase {

    private func makeOrganizer() throws -> (organizer: Organizer, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-org-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (Organizer(libraryRoot: root), root)
    }

    private func writeFile(_ name: String, in dir: URL) throws -> URL {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: url)
        return url
    }

    func test_organize_movesToMatchedSubpath() throws {
        let (organizer, root) = try makeOrganizer()
        defer { try? FileManager.default.removeItem(at: root) }

        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        let file = try writeFile("shot.png", in: inbox)
        let item = ShelfItem(
            sourceURL: file, displayName: "shot.png",
            ocrText: "Supabase auth error 401"
        )

        let moved = organizer.organize(item)

        XCTAssertEqual(moved.appName, "Supabase")
        XCTAssertTrue(moved.sourceURL.path.contains("Supabase"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.sourceURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path)) // original gone
    }

    func test_organize_detectsErrorCategoryIntoErrors() throws {
        let (organizer, root) = try makeOrganizer()
        defer { try? FileManager.default.removeItem(at: root) }

        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        let file = try writeFile("trace.png", in: inbox)
        let item = ShelfItem(sourceURL: file, displayName: "trace.png", ocrText: "Traceback error code 500")

        let moved = organizer.organize(item)

        XCTAssertEqual(moved.category, .error)
        XCTAssertTrue(moved.sourceURL.path.contains("Errors"))
    }

    func test_organize_noMatch_leavesFileInPlaceButStillDetects() throws {
        let engine = FolderRuleEngine(rules: []) // no rules
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("snapshelf-org-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let organizer = Organizer(libraryRoot: root, engine: engine)

        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        let file = try writeFile("note.png", in: inbox)
        let item = ShelfItem(sourceURL: file, displayName: "note.png", ocrText: "random grocery list")

        let moved = organizer.organize(item)

        XCTAssertEqual(moved.sourceURL, file) // unchanged
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path)) // still there
    }

    func test_organize_missingFile_returnsMetadataUnchanged() throws {
        let (organizer, root) = try makeOrganizer()
        defer { try? FileManager.default.removeItem(at: root) }

        let item = ShelfItem(
            sourceURL: URL(fileURLWithPath: "/no/such/file.png"),
            displayName: "file.png",
            ocrText: "Supabase migration"
        )
        let moved = organizer.organize(item)
        XCTAssertEqual(moved.sourceURL, item.sourceURL) // no move
        XCTAssertEqual(moved.appName, "Supabase") // but metadata detected
    }

    func test_organize_collisionGetsUniqueName() throws {
        let (organizer, root) = try makeOrganizer()
        defer { try? FileManager.default.removeItem(at: root) }

        // pre-create a file at the destination subpath with the same name
        let destDir = root.appendingPathComponent("Supabase", isDirectory: true)
        let preExisting = try writeFile("shot.png", in: destDir)

        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        let file = try writeFile("shot.png", in: inbox)
        let item = ShelfItem(sourceURL: file, displayName: "shot.png", ocrText: "Supabase")

        let moved = organizer.organize(item)

        XCTAssertNotEqual(moved.sourceURL, preExisting) // did not clobber
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.sourceURL.path))
        XCTAssertTrue(moved.sourceURL.lastPathComponent.hasPrefix("shot "))
    }
}
