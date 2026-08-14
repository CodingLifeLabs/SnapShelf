import XCTest
@testable import SnapShelfService
@testable import SnapShelfTypes

final class RuleBasedAIServiceTests: XCTestCase {

    private let service = RuleBasedAIService()

    // MARK: - rename

    func test_rename_usesFirstOcrLine() async throws {
        let item = ShelfItem(
            sourceURL: URL(fileURLWithPath: "/tmp/s.png"),
            displayName: "Screenshot 2026-08-14.png",
            ocrText: "Supabase Login Error\nTraceback (most recent call last)"
        )
        let name = try await service.rename(item)
        XCTAssertEqual(name, "Supabase Login Error")
    }

    func test_rename_fallsBackToAppWhenNoOcr() async throws {
        let item = ShelfItem(
            sourceURL: URL(fileURLWithPath: "/tmp/s.png"),
            displayName: "Screenshot.png",
            appName: "Chrome"
        )
        let name = try await service.rename(item)
        XCTAssertEqual(name, "Chrome screenshot")
    }

    func test_rename_keepsNameWhenNoContext() async throws {
        let item = ShelfItem(sourceURL: URL(fileURLWithPath: "/tmp/s.png"), displayName: "CleanShot.png")
        let name = try await service.rename(item)
        XCTAssertEqual(name, "CleanShot.png")
    }

    func test_rename_stripsInvalidFilenameCharacters() async throws {
        let item = ShelfItem(
            sourceURL: URL(fileURLWithPath: "/tmp/s.png"),
            displayName: "x.png",
            ocrText: "a/b\\c:d*e?f"
        )
        let name = try await service.rename(item)
        XCTAssertEqual(name, "abcdef")
    }

    func test_rename_capsLength() async throws {
        let long = String(repeating: "a", count: 200)
        let item = ShelfItem(sourceURL: URL(fileURLWithPath: "/tmp/s.png"), displayName: "x.png", ocrText: long)
        let svc = RuleBasedAIService(maxNameLength: 20)
        let name = try await svc.rename(item)
        XCTAssertLessThanOrEqual(name.count, 21) // 20 + ellipsis
        XCTAssertTrue(name.hasSuffix("…"))
    }

    // MARK: - summarize

    func test_summarize_joinsFirstThreeLines() async throws {
        let text = "Line one\nLine two\nLine three\nLine four"
        let summary = try await service.summarize(text)
        XCTAssertEqual(summary, "Line one · Line two · Line three")
    }

    func test_summarize_emptyReturnsEmpty() async throws {
        let summary = try await service.summarize("   ")
        XCTAssertEqual(summary, "")
    }

    func test_summarize_capsAt240Chars() async throws {
        let text = String(repeating: "word ", count: 100)
        let summary = try await service.summarize(text)
        XCTAssertLessThanOrEqual(summary.count, 241) // 240 + ellipsis
    }
}
