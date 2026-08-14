import Foundation
import SnapShelfTypes

// Sprint 5: pick the organizing subpath for an item from an ordered rule set.
// Highest-priority enabled match wins. Pure logic — fully testable.

public struct FolderRuleEngine: Sendable {
    public let rules: [FolderRule]

    public init(rules: [FolderRule]) {
        self.rules = rules
    }

    /// Default built-in rules (chat apps, code tools, categories). Lower priority.
    public static var defaultRules: [FolderRule] {
        [
            .init(kind: .app, pattern: "ChatGPT", targetSubpath: "ChatGPT", priority: 10),
            .init(kind: .app, pattern: "Claude", targetSubpath: "Claude", priority: 10),
            .init(kind: .app, pattern: "Figma", targetSubpath: "Figma", priority: 10),
            .init(kind: .app, pattern: "VSCode", targetSubpath: "VSCode", priority: 10),
            .init(kind: .app, pattern: "Slack", targetSubpath: "Slack", priority: 10),
            .init(kind: .app, pattern: "Discord", targetSubpath: "Discord", priority: 10),
            .init(kind: .app, pattern: "Chrome", targetSubpath: "Chrome", priority: 10),
            .init(kind: .app, pattern: "Safari", targetSubpath: "Safari", priority: 10),
            .init(kind: .keyword, pattern: "supabase", targetSubpath: "Supabase", priority: 20),
            .init(kind: .keyword, pattern: "stripe", targetSubpath: "Stripe", priority: 20),
            .init(kind: .category, pattern: ItemCategory.error.rawValue, targetSubpath: "Errors", priority: 15),
            .init(kind: .category, pattern: ItemCategory.receipt.rawValue, targetSubpath: "Receipts", priority: 15),
            .init(kind: .category, pattern: ItemCategory.invoice.rawValue, targetSubpath: "Invoices", priority: 15)
        ]
    }

    /// Returns the target subpath for the highest-priority enabled matching rule, else nil.
    public func target(for item: ShelfItem) -> String? {
        let active = rules
            .filter { $0.enabled }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        return active.first(where: { matches($0, item) })?.targetSubpath
    }

    public func matches(_ rule: FolderRule, _ item: ShelfItem) -> Bool {
        switch rule.kind {
        case .app:
            return item.appName?.localizedCaseInsensitiveContains(rule.pattern) ?? false
        case .category:
            return item.category?.rawValue == rule.pattern
        case .keyword:
            let ocr = item.ocrText?.localizedCaseInsensitiveContains(rule.pattern) ?? false
            let name = item.displayName.localizedCaseInsensitiveContains(rule.pattern)
            return ocr || name
        case .regex:
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: []) else { return false }
            let text = (item.ocrText ?? "") + " " + item.displayName
            let range = NSRange(text.startIndex..., in: text)
            return regex.firstMatch(in: text, options: [], range: range) != nil
        }
    }
}
