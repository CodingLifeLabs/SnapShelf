import Foundation

// Sprint 5: Smart Folder rules. A rule maps a captured item to an organizing subpath.

public enum FolderRuleKind: String, Sendable, Codable, CaseIterable, Equatable {
    case app
    case category
    case keyword
    case regex
}

public struct FolderRule: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public var kind: FolderRuleKind
    public var pattern: String
    public var targetSubpath: String
    public var priority: Int
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        kind: FolderRuleKind,
        pattern: String,
        targetSubpath: String,
        priority: Int = 0,
        enabled: Bool = true
    ) {
        self.id = id
        self.kind = kind
        self.pattern = pattern
        self.targetSubpath = targetSubpath
        self.priority = priority
        self.enabled = enabled
    }
}
