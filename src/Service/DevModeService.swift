import Foundation
import SnapShelfTypes

// Sprint 8: Dev Mode. Takes OCR text from an error screenshot and extracts
// code blocks, error lines and file references with plain regexes — fully
// offline. Also builds search URLs so the user can jump to StackOverflow /
// GitHub / Claude with one click.

public struct DevModeService: Sendable {
    /// Compiled once; patterns are static literals that cannot fail at runtime.
    static func regex(
        _ pattern: String,
        options: NSRegularExpression.Options = []
    ) -> NSRegularExpression {
        guard let compiled = try? NSRegularExpression(pattern: pattern, options: options) else {
            fatalError("invalid built-in pattern: \(pattern)")
        }
        return compiled
    }

    /// Lines that look like error/exception messages.
    private static let errorPatterns: [NSRegularExpression] = [
        regex(#"(?i)(fatal error|error:|exception|traceback|panic:|uncaught)"#),
        regex(#"(?i)\b(Segmentation fault|EXC_BAD_ACCESS|nil unwrapping|index out of range)\b"#)
    ]

    /// file.swift:123 or /path/to/file.swift references.
    private static let referencePattern = regex(
        #"[\w./~-]+\.(swift|ts|tsx|js|py|rb|go|rs|java|kt|c|cpp|h|m|mm)(:\d+)?"#
    )

    /// Fenced (```...```) code blocks.
    private static let fencedPattern = regex(
        #"```[^\n]*\n([\s\S]*?)```"#,
        options: [.anchorsMatchLines]
    )

    public init() {}

    /// Extract code/error material from OCR text (from an error screenshot).
    public func extract(fromOCRText text: String) -> DevModeExtraction {
        DevModeExtraction(
            codeBlocks: Self.fencedCodeBlocks(in: text) + Self.indentedCodeBlocks(in: text),
            errorLines: Self.errorLines(in: text),
            references: Self.references(in: text)
        )
    }

    /// A ready-to-paste search query from the extraction (error lines first).
    public func searchQuery(for extraction: DevModeExtraction) -> String {
        var parts: [String] = []
        if let first = extraction.errorLines.first { parts.append(first) }
        if let ref = extraction.references.first, parts.isEmpty { parts.append(ref) }
        if parts.isEmpty, let block = extraction.codeBlocks.first {
            parts.append(String(block.split(separator: "\n").first ?? ""))
        }
        return parts
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Google search URL for the query (distributes to SO/GH via site: terms
    /// handled by the caller — one URL keeps this testable and simple).
    public func searchURL(query: String, site: SearchSite = .google) -> URL? {
        guard !query.isEmpty else { return nil }
        guard var components = URLComponents(string: "https://www.google.com/search") else { return nil }
        let fullQuery = site == .google ? query : "\(site.siteQualifier) \(query)"
        components.queryItems = [URLQueryItem(name: "q", value: fullQuery)]
        return components.url
    }

    /// Claude.ai URL primed with the extracted material, if any.
    public func claudeURL(extraction: DevModeExtraction) -> URL? {
        let prompt = searchQuery(for: extraction)
        guard !prompt.isEmpty, var components = URLComponents(string: "https://claude.ai/new") else {
            return nil
        }
        components.queryItems = [URLQueryItem(name: "q", value: prompt)]
        return components.url
    }
}

public enum SearchSite: String, Sendable, Equatable, CaseIterable {
    case google
    case stackOverflow
    case github

    var siteQualifier: String {
        switch self {
        case .google: return ""
        case .stackOverflow: return "site:stackoverflow.com"
        case .github: return "site:github.com"
        }
    }
}

// MARK: - Extraction internals

private enum DevModePatterns {
    static let indentedLine = DevModeService.regex(#"^ {4,}\S"#)
}

extension DevModeService {
    /// Fenced ``` blocks verbatim (without the fences).
    static func fencedCodeBlocks(in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return fencedPattern.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let blockRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[blockRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Runs of ≥3 consecutive 4+-space-indented lines (terminal/stack output).
    static func indentedCodeBlocks(in text: String) -> [String] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [String] = []
        var current: [String] = []
        for line in lines {
            let isIndented = DevModePatterns.indentedLine.firstMatch(
                in: line,
                range: NSRange(line.startIndex..., in: line)
            ) != nil
            if isIndented {
                current.append(line.trimmingCharacters(in: .whitespaces))
            } else {
                if current.count >= 3 { blocks.append(current.joined(separator: "\n")) }
                current = []
            }
        }
        if current.count >= 3 { blocks.append(current.joined(separator: "\n")) }
        return blocks
    }

    /// Lines matching known error vocabulary.
    static func errorLines(in text: String) -> [String] {
        text.split(separator: "\n").filter { line in
            let range = NSRange(line.startIndex..., in: line)
            return errorPatterns.contains { pattern in
                pattern.firstMatch(in: String(line), range: range) != nil
            }
        }.map(String.init)
    }

    /// Distinct file references, order preserved.
    static func references(in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        let matches = referencePattern.matches(in: text, range: range)
        var seen = Set<String>()
        return matches.compactMap { match -> String? in
            guard let refRange = Range(match.range, in: text) else { return nil }
            let reference = String(text[refRange])
            if seen.insert(reference).inserted { return reference }
            return nil
        }
    }
}
