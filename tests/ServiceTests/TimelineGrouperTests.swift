import XCTest
@testable import SnapShelfService
@testable import SnapShelfTypes

final class TimelineGrouperTests: XCTestCase {

    private func item(_ name: String, at: TimeInterval) -> ShelfItem {
        ShelfItem(sourceURL: URL(fileURLWithPath: "/tmp/\(name)"), displayName: name,
                  capturedAt: Date(timeIntervalSince1970: at))
    }

    func test_group_bucketsByDayDescending() {
        let day1 = 1_700_000_000.0
        let day2 = day1 + 86_400 // next calendar day boundary may differ by tz; use startOfDay grouping
        let items = [
            item("a", at: day1),
            item("b", at: day2),
            item("c", at: day2 + 3600)
        ]
        let buckets = TimelineGrouper.group(items)
        XCTAssertEqual(buckets.count, 2)
        // newest day first
        XCTAssertEqual(buckets.first?.items.count, 2) // b, c
        // within a day, newest item first
        XCTAssertEqual(buckets.first?.items.first?.displayName, "c")
    }

    func test_group_emptyReturnsEmpty() {
        XCTAssertTrue(TimelineGrouper.group([]).isEmpty)
    }

    func test_group_sameDayProducesSingleBucket() {
        let base = 1_700_000_000.0
        let items = [item("a", at: base), item("b", at: base + 60), item("c", at: base + 120)]
        let buckets = TimelineGrouper.group(items)
        XCTAssertEqual(buckets.count, 1)
        XCTAssertEqual(buckets.first?.items.map(\.displayName), ["c", "b", "a"])
    }
}
