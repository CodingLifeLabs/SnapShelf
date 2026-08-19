import Foundation
import SnapShelfTypes

// Sprint 12 / ADR-0012: local-only usage counters. Same structure and security
// posture as PrivacyLog (Sprint 8): JSON lines, capped, never transmitted.
// Telemetry is permanently out of scope — this file exists so the user can see
// their own usage on the Privacy tab, nothing more.

public actor UsageStatsLog {
    private let fileURL: URL
    private let fileManager: FileManager
    private let maxEvents: Int

    /// Cap the retained log so a long-lived install can't grow it unboundedly.
    public init(fileURL: URL, fileManager: FileManager = .default, maxEvents: Int = 2000) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.maxEvents = maxEvents
    }

    /// Record one counted usage step (kind + timestamp only).
    public func record(_ event: UsageEvent) {
        var events = loadEvents()
        events.append(event)
        if events.count > maxEvents {
            events = Array(events.suffix(maxEvents))
        }
        persist(events)
    }

    /// Convenience: record a step happening "now".
    public func record(kind: UsageEventKind) {
        record(UsageEvent(kind: kind))
    }

    /// Chronological snapshot for the summary calculator.
    public func events() -> [UsageEvent] {
        loadEvents()
    }

    /// Remove every counted step (Privacy tab → Reset).
    public func clear() {
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Private

    private func loadEvents() -> [UsageEvent] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var events: [UsageEvent] = []
        for line in String(data: data, encoding: .utf8)?.split(separator: "\n") ?? [] {
            if let event = try? decoder.decode(UsageEvent.self, from: Data(String(line).utf8)) {
                events.append(event)
            }
        }
        return events
    }

    private func persist(_ events: [UsageEvent]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let lines = events.compactMap { event -> String? in
            guard let data = try? encoder.encode(event) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        try? fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? lines.joined(separator: "\n").appending("\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
