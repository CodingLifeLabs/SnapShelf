import Foundation
import SnapShelfTypes

// Sprint 6: group items into time buckets for the timeline view. Pure, testable.

public struct TimelineBucket: Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let startDate: Date
    public let items: [ShelfItem]

    public init(id: String, label: String, startDate: Date, items: [ShelfItem]) {
        self.id = id
        self.label = label
        self.startDate = startDate
        self.items = items
    }
}

public enum TimelineGrouper {
    /// Group items by calendar day, newest day first; items within a day newest-first.
    public static func group(_ items: [ShelfItem], calendar: Calendar = .current) -> [TimelineBucket] {
        let byDay = Dictionary(grouping: items) { calendar.startOfDay(for: $0.capturedAt) }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return byDay.map { day, dayItems in
            TimelineBucket(
                id: String(day.timeIntervalSince1970),
                label: formatter.string(from: day),
                startDate: day,
                items: dayItems.sorted { $0.capturedAt > $1.capturedAt }
            )
        }.sorted { $0.startDate > $1.startDate }
    }
}
