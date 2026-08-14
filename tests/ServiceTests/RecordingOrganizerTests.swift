import XCTest
@testable import SnapShelfService

// Sprint 8: RecordingOrganizer tests with temp-directory fixtures.

final class RecordingOrganizerTests: XCTestCase {
    var root: URL!
    var source: URL!
    var organizer: RecordingOrganizer!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec-org-\(UUID().uuidString)", isDirectory: true)
        source = FileManager.default.temporaryDirectory
            .appendingPathComponent("clip-\(UUID().uuidString).mov")
        try Data([0x00, 0x01]).write(to: source)
        organizer = RecordingOrganizer(recordingsRoot: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: source)
    }

    func testIsRecordingByExtension() {
        XCTAssertTrue(organizer.isRecording(URL(fileURLWithPath: "/tmp/a.MOV")))
        XCTAssertTrue(organizer.isRecording(URL(fileURLWithPath: "/tmp/a.mp4")))
        XCTAssertFalse(organizer.isRecording(URL(fileURLWithPath: "/tmp/a.png")))
    }

    func testMonthBucketFormat() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 8; comps.day = 15
        let date = Calendar.current.date(from: comps)!
        XCTAssertEqual(RecordingOrganizer.monthBucket(for: date), "2026/08")
    }

    func testOrganizeMovesIntoMonthBucket() throws {
        let dest = try XCTUnwrap(organizer.organize(source))
        XCTAssertTrue(dest.path.hasSuffix(".mov"))
        XCTAssertTrue(dest.path.contains("2026/"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
    }

    func testOrganizeIgnoresNonRecordings() throws {
        let png = source.deletingLastPathComponent()
            .appendingPathComponent("img-\(UUID().uuidString).png")
        try Data([0x00]).write(to: png)
        defer { try? FileManager.default.removeItem(at: png) }
        XCTAssertNil(organizer.organize(png))
        XCTAssertTrue(FileManager.default.fileExists(atPath: png.path))
    }

    func testOrganizeMissingFileReturnsNil() {
        let ghost = URL(fileURLWithPath: "/tmp/ghost-\(UUID().uuidString).mov")
        XCTAssertNil(organizer.organize(ghost))
    }

    func testListReturnsOrganizedFiles() {
        _ = organizer.organize(source)
        let files = organizer.list()
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files.first?.lastPathComponent, source.lastPathComponent)
    }
}
