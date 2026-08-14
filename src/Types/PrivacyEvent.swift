import Foundation

// Sprint 8: privacy audit trail + Dev Mode extracted payloads.

/// One outbound data-transfer event, shown on the Privacy dashboard.
public struct PrivacyEvent: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    /// Where the payload went (e.g. "OpenAI gpt-4o-mini", "Local (no transfer)").
    public let destination: String
    /// What left the device (e.g. "OCR text (1.2 KB)", "Image (downscaled)").
    public let payloadSummary: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        destination: String,
        payloadSummary: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.destination = destination
        self.payloadSummary = payloadSummary
    }
}

/// Code/error fragments extracted from an OCR'd screenshot by Dev Mode.
public struct DevModeExtraction: Sendable, Equatable {
    /// Raw code blocks found (fenced or indented) in the OCR text.
    public let codeBlocks: [String]
    /// Likely error/exception message lines.
    public let errorLines: [String]
    /// File paths or file:line references mentioned in the text.
    public let references: [String]

    public init(codeBlocks: [String], errorLines: [String], references: [String]) {
        self.codeBlocks = codeBlocks
        self.errorLines = errorLines
        self.references = references
    }

    public var isEmpty: Bool {
        codeBlocks.isEmpty && errorLines.isEmpty && references.isEmpty
    }
}
