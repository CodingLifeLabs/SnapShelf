import Foundation
import SnapShelfTypes

// Sprint 5: infer source app/category from OCR text + filename WITHOUT accessibility/TCC.
// (Real frontmost-window detection is an opt-in, accessibility-gated upgrade for later.)

public struct SourceDetector: Sendable {
    /// Known products mapped to a canonical app name, keyed by lowercase marker.
    public static let knownApps: [(marker: String, app: String)] = [
        ("chatgpt", "ChatGPT"), ("openai", "ChatGPT"),
        ("claude", "Claude"), ("anthropic", "Claude"),
        ("supabase", "Supabase"),
        ("vscode", "VSCode"), ("visual studio code", "VSCode"),
        ("xcode", "Xcode"),
        ("figma", "Figma"),
        ("notion", "Notion"),
        ("slack", "Slack"),
        ("discord", "Discord"),
        ("linear", "Linear"),
        ("github", "GitHub"),
        ("stripe", "Stripe"),
        ("safari", "Safari"),
        ("chrome", "Chrome"), ("google chrome", "Chrome"),
        ("firefox", "Firefox"),
        ("arc", "Arc"),
        ("terminal", "Terminal"), ("iterm", "Terminal")
    ]

    public init() {}

    /// Detect the source app from OCR text and filename (first match wins).
    public func detectApp(ocrText: String?, filename: String) -> String? {
        let haystack = ((ocrText ?? "") + " " + filename).lowercased()
        return Self.knownApps.first(where: { haystack.contains($0.marker) })?.app
    }

    /// Coarse category from app + OCR signals.
    public func detectCategory(app: String?, ocrText: String?) -> ItemCategory {
        let text = (ocrText ?? "").lowercased()
        if text.contains("traceback") || text.contains("exception") || text.contains("error code")
            || text.contains("fatal") || text.contains("undefined is not") {
            return .error
        }
        if let app {
            switch app {
            case "ChatGPT", "Claude": return .chat
            case "VSCode", "Xcode": return .code
            case "Terminal": return .terminal
            case "Figma": return .design
            case "Slack", "Discord": return .chat
            default: break
            }
        }
        if text.contains("receipt") || text.contains("total") || text.contains("amount due") { return .receipt }
        if text.contains("invoice") || text.contains("bill to") { return .invoice }
        return .other
    }
}
