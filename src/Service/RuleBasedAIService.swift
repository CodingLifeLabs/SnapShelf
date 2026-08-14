import Foundation
import SnapShelfTypes

/// Local, offline, privacy-safe heuristic AI service. No network, no keys.
/// Used as the default rename provider and as the fallback when real AI is unavailable.
public struct RuleBasedAIService: AIService {
    private let maxNameLength: Int

    public init(maxNameLength: Int = 48) {
        self.maxNameLength = maxNameLength
    }

    public func rename(_ item: ShelfItem) async throws -> String {
        // Prefer the first meaningful OCR line; else app context; else keep current name.
        if let candidate = firstLine(item.ocrText), !candidate.isEmpty {
            return sanitize(candidate)
        }
        if let app = item.appName, !app.isEmpty {
            return sanitize("\(app) screenshot")
        }
        return item.displayName
    }

    public func summarize(_ text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let lines = trimmed
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // Take up to 3 leading lines, capped at 240 chars.
        let picked = lines.prefix(3).joined(separator: " · ")
        if picked.count <= 240 { return picked }
        let end = picked.index(picked.startIndex, offsetBy: 240)
        return String(picked[..<end]) + "…"
    }

    // MARK: - Helpers

    private func firstLine(_ text: String?) -> String? {
        guard let text else { return nil }
        return text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty })
    }

    /// Strip characters unsafe in filenames; collapse whitespace; cap length.
    public func sanitize(_ raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = raw
            .components(separatedBy: invalid)
            .joined()
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard !cleaned.isEmpty else { return "Screenshot" }
        if cleaned.count <= maxNameLength { return cleaned }
        let end = cleaned.index(cleaned.startIndex, offsetBy: maxNameLength)
        return String(cleaned[..<end]) + "…"
    }
}
