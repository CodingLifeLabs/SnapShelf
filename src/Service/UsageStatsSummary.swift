import Foundation
import SnapShelfTypes

// Sprint 12 / ADR-0012: pure aggregation over the local usage events.
// No I/O, no clock reads beyond the passed-in `now` — fully unit-testable.

/// Aggregate counters shown on Settings → Privacy ("Your usage, local only").
public struct UsageStatsSummary: Sendable, Equatable {
    public let totalCaptured: Int
    public let totalSearches: Int
    /// searchHit / searched; nil when no searches yet (shown as "—").
    public let searchHitRate: Double?
    public let totalCopied: Int
    public let activeDays: Int

    public init(
        totalCaptured: Int,
        totalSearches: Int,
        searchHitRate: Double?,
        totalCopied: Int,
        activeDays: Int
    ) {
        self.totalCaptured = totalCaptured
        self.totalSearches = totalSearches
        self.searchHitRate = searchHitRate
        self.totalCopied = totalCopied
        self.activeDays = activeDays
    }

    /// Empty summary (no events recorded yet).
    public static let empty = UsageStatsSummary(
        totalCaptured: 0,
        totalSearches: 0,
        searchHitRate: nil,
        totalCopied: 0,
        activeDays: 0
    )
}

public enum UsageStatsSummaryCalculator {
    /// Aggregate a chronological event list into display counters.
    /// - Parameters:
    ///   - events: events in any order (sorted internally).
    ///   - calendar: used for counting distinct active days.
    public static func summarize(
        _ events: [UsageEvent],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> UsageStatsSummary {
        let captured = events.filter { $0.kind == .captured }.count
        let searched = events.filter { $0.kind == .searched }.count
        let searchHits = events.filter { $0.kind == .searchHit }.count
        let copied = events.filter { $0.kind == .copied }.count
        let hitRate: Double? = searched > 0 ? Double(searchHits) / Double(searched) : nil
        let days = Set(events.map { calendar.startOfDay(for: $0.timestamp) }).count
        return UsageStatsSummary(
            totalCaptured: captured,
            totalSearches: searched,
            searchHitRate: hitRate,
            totalCopied: copied,
            activeDays: days
        )
    }

    /// Events recorded within the last `days` calendar days (inclusive of today).
    public static func eventsLast(
        _ events: [UsageEvent],
        days: Int,
        now: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [UsageEvent] {
        guard days > 0 else { return [] }
        let cutoff = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        return events.filter { $0.timestamp >= cutoff }
    }
}
