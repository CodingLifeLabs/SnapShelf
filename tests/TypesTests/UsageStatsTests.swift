import XCTest
@testable import SnapShelfTypes

// Sprint 12: UsageEvent kind coverage + Codable round-trip (ADR-0012).

final class UsageStatsTests: XCTestCase {
    func testAllKindsRoundTripThroughCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for kind in UsageEventKind.allCases {
            let event = UsageEvent(kind: kind)
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(UsageEvent.self, from: data)
            XCTAssertEqual(decoded, event)
            XCTAssertEqual(decoded.kind, kind)
        }
    }

    func testAllSixKindsExist() {
        XCTAssertEqual(
            Set(UsageEventKind.allCases),
            Set([.captured, .searched, .searchHit, .copied, .pinned, .stowed])
        )
    }

    func testKindRawValuesAreStable() {
        // The JSONL file persists raw values — renaming breaks old logs.
        XCTAssertEqual(UsageEventKind.captured.rawValue, "captured")
        XCTAssertEqual(UsageEventKind.searched.rawValue, "searched")
        XCTAssertEqual(UsageEventKind.searchHit.rawValue, "searchHit")
        XCTAssertEqual(UsageEventKind.copied.rawValue, "copied")
        XCTAssertEqual(UsageEventKind.pinned.rawValue, "pinned")
        XCTAssertEqual(UsageEventKind.stowed.rawValue, "stowed")
    }

    func testEventCarriesIdentityAndTimestamp() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let event = UsageEvent(id: id, timestamp: date, kind: .copied)
        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.timestamp, date)
        XCTAssertEqual(event.kind, .copied)
    }
}
