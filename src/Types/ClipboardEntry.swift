import Foundation

// SnapShelfTypes — pure domain value types. No framework dependencies.

/// One captured pasteboard image in the Smart Clipboard history (Sprint 7).
/// Stores downscaled PNG bytes so the history stays local and bounded.
public struct ClipboardEntry: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let image: Data
    public let copiedAt: Date

    public init(
        id: UUID = UUID(),
        image: Data,
        copiedAt: Date = Date()
    ) {
        self.id = id
        self.image = image
        self.copiedAt = copiedAt
    }
}
