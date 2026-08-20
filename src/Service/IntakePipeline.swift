import Foundation
import SnapShelfTypes
import SnapShelfRepo

// SnapShelfService — business logic. Sprint 1: intake (new file -> ShelfItem -> repo).
// Later sprints add OCR, AI rename/summary, classification, organizing here.

public protocol IntakePipeline: Sendable {
    /// Turn a newly detected file URL into a persisted ShelfItem.
    func ingest(url: URL) async throws -> ShelfItem
}

/// Pure, testable helpers shared by the intake flow.
public enum IntakeSupport {
    /// File creation date from filesystem attributes; nil if unavailable.
    public static func creationDate(of url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.creationDateKey])
        return values?.creationDate
    }

    /// Strip macOS screenshot noise: "Screenshot 2026-08-14 at 10.22.03.png"
    /// -> "Screenshot 2026-08-14.png". Unchanged if the pattern is absent.
    public static func beautify(_ name: String) -> String {
        var result = name
        if let range = result.range(of: #" at \d{1,2}\.\d{2}\.\d{2}"#, options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result
    }

    /// Sprint 13 / ADR-0013: pure settle policy — the file is considered
    /// settled once two consecutive size samples agree.
    public static func isStable(sampling sizes: [Int]) -> Bool {
        guard sizes.count >= 2 else { return false }
        return sizes[sizes.count - 1] == sizes[sizes.count - 2]
    }
}

public final class DefaultIntakePipeline: IntakePipeline {
    private let repository: any ShelfItemRepository
    private let ocrService: OCRService?
    private let aiService: AIService?
    private let renameEnabled: Bool
    private let organizer: Organizer?
    private let clock: @Sendable () -> Date
    /// Sprint 13 / ADR-0013: waits for the capture file to stop changing size
    /// before OCR reads it (mid-write reads made Vision fail silently).
    private let settleAttempts: Int
    private let settleInterval: UInt64
    private let sleep: @Sendable (UInt64) async -> Void

    public init(
        repository: any ShelfItemRepository,
        ocrService: OCRService? = nil,
        aiService: AIService? = nil,
        renameEnabled: Bool = false,
        organizer: Organizer? = nil,
        clock: @escaping @Sendable () -> Date = { Date() },
        settleAttempts: Int = 4,
        settleIntervalNanos: UInt64 = 350_000_000,
        sleep: (@Sendable (UInt64) async -> Void)? = nil
    ) {
        self.repository = repository
        self.ocrService = ocrService
        self.aiService = aiService
        self.renameEnabled = renameEnabled
        self.organizer = organizer
        self.clock = clock
        self.settleAttempts = max(2, settleAttempts)
        self.settleInterval = settleIntervalNanos
        self.sleep = sleep ?? { try? await Task.sleep(nanoseconds: $0) }
    }

    public func ingest(url: URL) async throws -> ShelfItem {
        await settle(url: url)
        let original = url.lastPathComponent
        var item = ShelfItem(
            sourceURL: url,
            displayName: IntakeSupport.beautify(original),
            originalName: original,
            capturedAt: IntakeSupport.creationDate(of: url) ?? clock(),
            ingestedAt: clock()
        )
        try await repository.upsert(item)
        // OCR is best-effort: a failure must never lose the captured item.
        // Sprint 13: failures are recorded (`.failed`) instead of being swallowed.
        if let ocr = ocrService {
            do {
                let text = try await ocr.recognize(url)
                if !text.isEmpty {
                    try await repository.setOCR(id: item.id, text: text)
                    item.ocrText = text
                    item.ocrStatus = .ok
                    try? await repository.setOCRStatus(id: item.id, status: .ok)
                }
            } catch {
                item.ocrStatus = .failed
                try? await repository.setOCRStatus(id: item.id, status: .failed)
            }
        }
        // AI rename is best-effort and opt-in; falls through silently on failure.
        if renameEnabled, let ai = aiService, let name = try? await ai.rename(item), !name.isEmpty {
            item.displayName = name
        }
        // Smart Folder organizing: detect source + move into the library (best-effort).
        if let organizer {
            item = organizer.organize(item)
        }
        try await repository.upsert(item)
        return item
    }

    /// Wait until the file size stops changing (or attempts run out).
    /// The watcher fires on the first `.write` — often mid-capture.
    private func settle(url: URL) async {
        var sizes: [Int] = [fileSize(url)]
        for _ in 0..<(settleAttempts - 1) {
            await sleep(settleInterval)
            sizes.append(fileSize(url))
            if IntakeSupport.isStable(sampling: sizes) { return }
        }
    }

    /// Fresh `stat` on every call — `URL.resourceValues` would return a cached
    /// size, making consecutive probes compare stale values and settle early.
    private func fileSize(_ url: URL) -> Int {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? Int) ?? 0
    }
}
