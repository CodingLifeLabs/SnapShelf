import XCTest
import os
@testable import SnapShelfRuntime

final class DirectoryWatcherTests: XCTestCase {

    // MARK: - Pure diff logic

    func test_newFiles_returnsOnlyNewMatchingFiles() async throws {
        // Arrange
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let watcher = DirectoryWatcher(directory: dir, fileExtensions: ["png"]) { _ in }

        // Act
        let first = await watcher.newFiles(from: ["a.png", "b.txt", "c.png"])
        let second = await watcher.newFiles(from: ["a.png", "d.png"])

        // Assert
        XCTAssertEqual(Set(first), ["a.png", "c.png"]) // ignores .txt, both pngs are new
        XCTAssertEqual(Set(second), ["d.png"])         // a.png already known
    }

    func test_newFiles_ignoresCaseAndNonImageExtensions() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let watcher = DirectoryWatcher(directory: dir, fileExtensions: ["png", "jpg"]) { _ in }
        let added = await watcher.newFiles(from: ["PHOTO.JPG", "readme.md", "x.png"])

        XCTAssertEqual(Set(added), ["PHOTO.JPG", "x.png"])
    }

    // MARK: - Sprint 13 / ADR-0013: dotfile temp captures

    func test_newFiles_ignoresDotPrefixedTempFiles() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let watcher = DirectoryWatcher(directory: dir, fileExtensions: ["png"]) { _ in }

        // macOS screencapture writes ".Name.png" first, renames when complete.
        let tempOnly = await watcher.newFiles(from: [".Screenshot 2026-08-20 at 10.00.00.png"])
        XCTAssertTrue(tempOnly.isEmpty, "dot-prefixed temp files must not be ingested")

        let renamed = await watcher.newFiles(from: ["Screenshot 2026-08-20 at 10.00.00.png"])
        XCTAssertEqual(Set(renamed), ["Screenshot 2026-08-20 at 10.00.00.png"],
                       "the renamed final file must be ingested")
    }

    // MARK: - Live dispatch source (integration)

    func test_start_detectsFileAddedAfterStart() async throws {
        // Arrange
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshelf-watch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let expectation = expectation(description: "new file detected")
        let detected = OSAllocatedUnfairLock<URL?>(initialState: nil)

        let watcher = DirectoryWatcher(directory: dir, fileExtensions: ["png"]) { url in
            detected.withLock { $0 = url }
            expectation.fulfill()
        }

        // Act
        try await watcher.start()

        // small delay so the source is armed before we write
        try await Task.sleep(nanoseconds: 150_000_000)

        let fileURL = dir.appendingPathComponent("incoming-\(UUID().uuidString).png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: fileURL)

        // Assert
        await fulfillment(of: [expectation], timeout: 5.0)
        await watcher.stop()
        let detectedURL = detected.withLock { $0 }
        XCTAssertEqual(detectedURL?.lastPathComponent, fileURL.lastPathComponent)
    }
}
