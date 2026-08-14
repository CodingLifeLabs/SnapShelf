import Foundation
import SnapShelfTypes

// Sprint 7: Smart Clipboard — local pasteboard-image history.
// Capped FIFO; JSON-persisted so the history survives relaunches.
// Entries store downscaled PNG bytes (the capture model bounds the size),
// keeping everything on-device.

public actor ClipboardHistoryRepository {
    public static let defaultLimit = 50

    private let storeFile: URL?
    private let limit: Int
    private var entries: [ClipboardEntry] = []
    private var loaded = false

    public init(storeFile: URL? = nil, limit: Int = ClipboardHistoryRepository.defaultLimit) {
        self.storeFile = storeFile
        self.limit = max(1, limit)
    }

    // MARK: - History

    /// Insert at the front; drops the oldest entries beyond the limit.
    public func record(_ entry: ClipboardEntry) {
        ensureLoaded()
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
        persist()
    }

    /// Newest-first snapshot of the history.
    public func all() -> [ClipboardEntry] {
        ensureLoaded()
        return entries
    }

    public func remove(id: UUID) {
        ensureLoaded()
        entries.removeAll { $0.id == id }
        persist()
    }

    public func clear() {
        ensureLoaded()
        entries = []
        persist()
    }

    // MARK: - Internals

    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true
        guard let storeFile,
              FileManager.default.fileExists(atPath: storeFile.path),
              let data = try? Data(contentsOf: storeFile),
              let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else { return }
        entries = Array(decoded.prefix(limit))
    }

    private func persist() {
        guard let storeFile else { return }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: storeFile, options: .atomic)
        }
    }
}
