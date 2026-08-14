import Foundation
import SnapShelfTypes

// Sprint 7: near-duplicate detection. Groups screenshots whose pHashes fall
// within a small Hamming distance (default 3/64 bits ≈ 95% similar) and
// recommends one keeper per group (the newest capture).

/// A similarity cluster with the recommended keeper and its duplicates.
public struct DuplicateGroup: Identifiable, Sendable, Equatable {
    public let keeper: ShelfItem
    public let duplicates: [ShelfItem]

    public var id: UUID { keeper.id }

    public init(keeper: ShelfItem, duplicates: [ShelfItem]) {
        self.keeper = keeper
        self.duplicates = duplicates
    }
}

public struct Deduplicator: Sendable {
    public let hasher: PerceptualHash
    /// Max differing bits for "similar" (3/64 ≈ 95% similarity).
    public let maxHammingDistance: Int

    public init(
        hasher: PerceptualHash = PerceptualHash(),
        maxHammingDistance: Int = 3
    ) {
        self.hasher = hasher
        self.maxHammingDistance = max(0, maxHammingDistance)
    }

    /// Groups visually similar items. Groups with a single member are omitted.
    /// Unreadable files (nil hash) are never grouped.
    public func duplicateGroups(among items: [ShelfItem]) -> [DuplicateGroup] {
        // Newest-first so the keeper of each cluster is the most recent capture.
        let sorted = items.sorted { $0.capturedAt > $1.capturedAt }
        var hashes: [UUID: UInt64] = [:]
        for item in sorted {
            if let hash = hasher.hash(of: item.sourceURL) {
                hashes[item.id] = hash
            }
        }

        var assigned = Set<UUID>()
        var groups: [DuplicateGroup] = []
        for candidate in sorted where hashes[candidate.id] != nil && !assigned.contains(candidate.id) {
            assigned.insert(candidate.id)
            var duplicates: [ShelfItem] = []
            for other in sorted where hashes[other.id] != nil
                && !assigned.contains(other.id)
                && PerceptualHash.hammingDistance(hashes[candidate.id]!, hashes[other.id]!) <= maxHammingDistance {
                assigned.insert(other.id)
                duplicates.append(other)
            }
            if !duplicates.isEmpty {
                groups.append(DuplicateGroup(keeper: candidate, duplicates: duplicates))
            }
        }
        return groups
    }
}
