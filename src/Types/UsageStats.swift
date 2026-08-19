import Foundation

// Sprint 12 / ADR-0012: local-only usage statistics for the self-report PMF
// signal. An event carries ONLY a kind and a timestamp — never screenshot
// content, file names, or OCR text. Nothing ever leaves the device.

/// The usage loop steps we count. Remote telemetry is permanently out of scope.
public enum UsageEventKind: String, Sendable, Codable, CaseIterable {
    case captured
    case searched
    case searchHit
    case copied
    case pinned
    case stowed
}

/// One counted usage step, persisted as a JSON line by UsageStatsLog.
public struct UsageEvent: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let kind: UsageEventKind

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: UsageEventKind
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
    }
}
