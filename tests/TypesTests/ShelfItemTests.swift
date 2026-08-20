import XCTest
@testable import SnapShelfTypes

final class ShelfItemTests: XCTestCase {

    // MARK: - Identity & defaults

    func test_defaultStatus_isResting() {
        // Arrange / Act
        let item = ShelfItem(sourceURL: URL(fileURLWithPath: "/tmp/a.png"), displayName: "a")
        // Assert
        XCTAssertEqual(item.status, .resting)
        XCTAssertNil(item.category)
        XCTAssertNil(item.appName)
    }

    func test_isSurfaced_trueForRestingAndPinned_falseForStowedDeleted() {
        let base = URL(fileURLWithPath: "/tmp/a.png")
        XCTAssertTrue(ShelfItem(sourceURL: base, displayName: "a", status: .resting).isSurfaced)
        XCTAssertTrue(ShelfItem(sourceURL: base, displayName: "a", status: .pinned).isSurfaced)
        XCTAssertFalse(ShelfItem(sourceURL: base, displayName: "a", status: .stowed).isSurfaced)
        XCTAssertFalse(ShelfItem(sourceURL: base, displayName: "a", status: .deleted).isSurfaced)
    }

    // MARK: - Codable round-trip

    func test_codable_roundTrip_preservesAllFields() throws {
        // Arrange
        let original = ShelfItem(
            sourceURL: URL(fileURLWithPath: "/tmp/shot.png"),
            displayName: "Supabase Login Error.png",
            originalName: "Screenshot 2026-08-14 at 10.22.png",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            ingestedAt: Date(timeIntervalSince1970: 1_700_000_100),
            appName: "Chrome",
            category: .error,
            status: .pinned,
            ocrText: "error text",
            ocrStatus: .ok
        )
        // Act
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShelfItem.self, from: data)
        // Assert
        XCTAssertEqual(decoded, original)
    }

    // MARK: - OCR status (Sprint 13 / ADR-0013)

    func test_ocrStatus_defaultsToNil_andRoundTripsAllCases() throws {
        // Arrange: default is nil (= pre-Sprint-13 rows decode without the key).
        let plain = ShelfItem(sourceURL: URL(fileURLWithPath: "/tmp/a.png"), displayName: "a")
        XCTAssertNil(plain.ocrStatus)

        // Act / Assert: every case round-trips.
        for status in [OCRStatus.ok, .failed] {
            let item = ShelfItem(
                sourceURL: URL(fileURLWithPath: "/tmp/a.png"),
                displayName: "a",
                ocrStatus: status
            )
            let decoded = try JSONDecoder().decode(ShelfItem.self, from: JSONEncoder().encode(item))
            XCTAssertEqual(decoded.ocrStatus, status)
        }

        // Decoding JSON without the key still yields nil (backward compatible).
        let legacyJSON = """
        {"id":"\(UUID().uuidString)","sourceURL":"file:///tmp/a.png","displayName":"a",\
        "capturedAt":0,"ingestedAt":0,"status":"resting"}
        """
        let legacy = try JSONDecoder().decode(ShelfItem.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(legacy.ocrStatus)
    }

    func test_category_allCases_codable() throws {
        for category in ItemCategory.allCases {
            let raw = try JSONEncoder().encode(category)
            let back = try JSONDecoder().decode(ItemCategory.self, from: raw)
            XCTAssertEqual(back, category)
        }
    }

    // MARK: - Equatable

    func test_twoItemsWithSameID_areEqual_regardlessOfMutation() {
        // Arrange — `b` is a copy so timestamps are identical (two Date() defaults would differ).
        let id = UUID()
        let template = ShelfItem(id: id, sourceURL: URL(fileURLWithPath: "/tmp/a.png"), displayName: "a")
        var a = template
        let b = template

        // Act / Assert
        XCTAssertEqual(a, b)
        a.displayName = "changed"
        XCTAssertNotEqual(a, b)
    }
}
