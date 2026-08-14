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
}

public final class DefaultIntakePipeline: IntakePipeline {
    private let repository: any ShelfItemRepository
    private let ocrService: OCRService?
    private let aiService: AIService?
    private let renameEnabled: Bool
    private let organizer: Organizer?
    private let clock: @Sendable () -> Date

    public init(
        repository: any ShelfItemRepository,
        ocrService: OCRService? = nil,
        aiService: AIService? = nil,
        renameEnabled: Bool = false,
        organizer: Organizer? = nil,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.ocrService = ocrService
        self.aiService = aiService
        self.renameEnabled = renameEnabled
        self.organizer = organizer
        self.clock = clock
    }

    public func ingest(url: URL) async throws -> ShelfItem {
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
        if let ocr = ocrService, let text = try? await ocr.recognize(url), !text.isEmpty {
            try await repository.setOCR(id: item.id, text: text)
            item.ocrText = text
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
}
