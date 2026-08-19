import XCTest
@testable import SnapShelfService
@testable import SnapShelfTypes

// Sprint 12: pure aggregation over usage events (ADR-0012).

final class UsageStatsSummaryTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    func testEmptyEventsGiveEmptySummary() {
        let summary = UsageStatsSummaryCalculator.summarize([])
        XCTAssertEqual(summary, .empty)
        XCTAssertEqual(summary.searchHitRate, nil)
        XCTAssertEqual(summary.activeDays, 0)
    }

    func testCountsByKind() {
        let events = [
            UsageEvent(timestamp: date(2026, 8, 1), kind: .captured),
            UsageEvent(timestamp: date(2026, 8, 1), kind: .captured),
            UsageEvent(timestamp: date(2026, 8, 1), kind: .searched),
            UsageEvent(timestamp: date(2026, 8, 1), kind: .searchHit),
            UsageEvent(timestamp: date(2026, 8, 1), kind: .copied),
            UsageEvent(timestamp: date(2026, 8, 1), kind: .pinned),
            UsageEvent(timestamp: date(2026, 8, 1), kind: .stowed)
        ]
        let summary = UsageStatsSummaryCalculator.summarize(events)
        XCTAssertEqual(summary.totalCaptured, 2)
        XCTAssertEqual(summary.totalSearches, 1)
        XCTAssertEqual(summary.totalCopied, 1)
        XCTAssertEqual(summary.searchHitRate, 1.0)
    }

    func testHitRateZeroDenominatorIsNil() {
        let events = [
            UsageEvent(timestamp: date(2026, 8, 1), kind: .captured),
            UsageEvent(timestamp: date(2026, 8, 1), kind: .searchHit)
        ]
        let summary = UsageStatsSummaryCalculator.summarize(events)
        XCTAssertNil(summary.searchHitRate)
    }

    func testHitRateFraction() {
        let base = date(2026, 8, 1)
        let searches = (0..<4).map { _ in UsageEvent(timestamp: base, kind: .searched) }
        let hits = (0..<1).map { _ in UsageEvent(timestamp: base, kind: .searchHit) }
        let summary = UsageStatsSummaryCalculator.summarize(searches + hits)
        XCTAssertEqual(summary.searchHitRate ?? -1, 0.25, accuracy: 0.0001)
    }

    func testActiveDaysCountsDistinctDaysNotEvents() {
        let events = [
            UsageEvent(timestamp: date(2026, 8, 1, 1), kind: .captured),
            UsageEvent(timestamp: date(2026, 8, 1, 23), kind: .captured),
            UsageEvent(timestamp: date(2026, 8, 2), kind: .searched),
            UsageEvent(timestamp: date(2026, 8, 5), kind: .copied)
        ]
        let summary = UsageStatsSummaryCalculator.summarize(events)
        XCTAssertEqual(summary.activeDays, 3)
    }

    func testEventsLastFiltersByWindow() {
        let now = date(2026, 8, 19)
        let recent = UsageEvent(timestamp: date(2026, 8, 18), kind: .captured)
        let old = UsageEvent(timestamp: date(2026, 8, 1), kind: .captured)
        let filtered = UsageStatsSummaryCalculator.eventsLast([recent, old], days: 7, now: now, calendar: calendar)
        XCTAssertEqual(filtered, [recent])
    }

    func testEventsLastZeroOrNegativeDaysIsEmpty() {
        let now = date(2026, 8, 19)
        let events = [UsageEvent(timestamp: now, kind: .captured)]
        XCTAssertTrue(UsageStatsSummaryCalculator.eventsLast(events, days: 0, now: now, calendar: calendar).isEmpty)
        XCTAssertTrue(UsageStatsSummaryCalculator.eventsLast(events, days: -3, now: now, calendar: calendar).isEmpty)
    }

    func testEventsLastIncludesBoundaryDay() {
        let now = date(2026, 8, 19)
        // days:1 → cutoff is 08-18 12:00; an event on 08-18 12:00 is included.
        let boundary = UsageEvent(timestamp: date(2026, 8, 18), kind: .searched)
        let filtered = UsageStatsSummaryCalculator.eventsLast([boundary], days: 1, now: now, calendar: calendar)
        XCTAssertEqual(filtered, [boundary])
    }
}
