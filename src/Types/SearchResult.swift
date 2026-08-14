import Foundation

// Sprint 3: search result carrying a matched item + highlighted excerpt.

public struct SearchResult: Identifiable, Sendable, Equatable {
    public let item: ShelfItem
    public var excerpt: String

    public var id: UUID { item.id }

    public init(item: ShelfItem, excerpt: String) {
        self.item = item
        self.excerpt = excerpt
    }
}
