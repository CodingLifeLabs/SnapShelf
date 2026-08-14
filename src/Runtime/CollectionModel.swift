import Foundation
import SnapShelfTypes

// Sprint 6: in-memory manual collections (persistence wired in a later sprint).

@MainActor
@Observable
public final class CollectionModel {
    public private(set) var collections: [SnapCollection] = []

    public init() {}

    @discardableResult
    public func create(name: String) -> SnapCollection {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let collection = SnapCollection(name: trimmed.isEmpty ? "Untitled" : trimmed)
        collections.append(collection)
        return collection
    }

    public func add(_ itemID: UUID, to collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[index].itemIDs.insert(itemID)
    }

    public func remove(_ itemID: UUID, from collectionID: UUID) {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return }
        collections[index].itemIDs.remove(itemID)
    }

    public func delete(_ collectionID: UUID) {
        collections.removeAll { $0.id == collectionID }
    }

    public func items(in collectionID: UUID, from all: [ShelfItem]) -> [ShelfItem] {
        guard let collection = collections.first(where: { $0.id == collectionID }) else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return collection.itemIDs.compactMap { byID[$0] }
            .sorted { $0.capturedAt > $1.capturedAt }
    }
}
