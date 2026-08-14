import Foundation

// Sprint 6: manual collections (AI auto-collections are opt-in, future).

public struct SnapCollection: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var itemIDs: Set<UUID>

    public init(id: UUID = UUID(), name: String, itemIDs: Set<UUID> = []) {
        self.id = id
        self.name = name
        self.itemIDs = itemIDs
    }
}
