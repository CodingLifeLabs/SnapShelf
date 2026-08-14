import Foundation

// SnapShelfTypes — pure domain value types. No framework dependencies.

/// Coarse AI/subject classification for a captured screenshot.
public enum ItemCategory: String, Sendable, Codable, CaseIterable, Equatable {
    case chat
    case code
    case error
    case receipt
    case invoice
    case design
    case meme
    case terminal
    case document
    case other
}

/// Lifecycle state of a shelf item.
public enum ShelfItemStatus: String, Sendable, Codable, Equatable {
    case resting   // freshly captured, visible on the shelf
    case stowed    // moved off the shelf into history
    case pinned    // kept visible (always-on-shelf)
    case deleted   // logically deleted (pending trash)
}

/// Core entity: one captured screenshot on the shelf.
public struct ShelfItem: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public var sourceURL: URL
    public var displayName: String
    public var originalName: String?
    public var capturedAt: Date
    public var ingestedAt: Date
    public var appName: String?
    public var category: ItemCategory?
    public var status: ShelfItemStatus
    public var ocrText: String?
    public var note: String?

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        displayName: String,
        originalName: String? = nil,
        capturedAt: Date = Date(),
        ingestedAt: Date = Date(),
        appName: String? = nil,
        category: ItemCategory? = nil,
        status: ShelfItemStatus = .resting,
        ocrText: String? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.displayName = displayName
        self.originalName = originalName
        self.capturedAt = capturedAt
        self.ingestedAt = ingestedAt
        self.appName = appName
        self.category = category
        self.status = status
        self.ocrText = ocrText
        self.note = note
    }
}

public extension ShelfItem {
    /// True when the item is currently surfaced on the shelf (resting or pinned).
    var isSurfaced: Bool {
        status == .resting || status == .pinned
    }
}
