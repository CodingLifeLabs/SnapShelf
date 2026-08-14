import Foundation
import SnapShelfTypes

// Sprint 8: append-only local log of outbound data transfers. The Privacy
// dashboard reads this so users can audit exactly what left the device.
// Pure Foundation (JSON lines) — no cloud, no telemetry.

public actor PrivacyLog {
    private let fileURL: URL
    private let fileManager: FileManager
    private let maxEvents: Int

    /// Cap the retained log so an old install can't grow it unboundedly.
    public init(fileURL: URL, fileManager: FileManager = .default, maxEvents: Int = 500) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.maxEvents = maxEvents
    }

    /// Record one outbound transfer (or an explicit "local-only" no-transfer event).
    public func record(_ event: PrivacyEvent) {
        var events = loadEvents()
        events.append(event)
        if events.count > maxEvents {
            events = Array(events.suffix(maxEvents))
        }
        persist(events)
    }

    /// Newest-first snapshot for the dashboard.
    public func all() -> [PrivacyEvent] {
        loadEvents().reversed()
    }

    /// Remove every recorded event.
    public func clear() {
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Private

    private func loadEvents() -> [PrivacyEvent] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var events: [PrivacyEvent] = []
        for line in String(data: data, encoding: .utf8)?.split(separator: "\n") ?? [] {
            if let event = try? decoder.decode(PrivacyEvent.self, from: Data(String(line).utf8)) {
                events.append(event)
            }
        }
        return events
    }

    private func persist(_ events: [PrivacyEvent]) {
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
