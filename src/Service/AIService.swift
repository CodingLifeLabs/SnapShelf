import Foundation
import SnapShelfTypes

// Sprint 4: AI provider abstraction. rename/summarize are the core capabilities.
// Implementations: RuleBasedAIService (local fallback), FoundationModelsAIService
// (on-device, macOS 26+), HTTPAIService (OpenAI/Claude/Gemini), OllamaAIService.
// All cloud calls are opt-in (AIProviderConfig.enabled) and require a SecretStore key.

public enum AIError: Error, Equatable {
    case unavailable        // provider not supported on this OS / not configured
    case missingKey         // no API key in SecretStore
    case requestFailed(String)
    case decodeFailed(String)
}

public protocol AIService: Sendable {
    /// Suggest a new display name (no extension) for an item, using its OCR/app context.
    func rename(_ item: ShelfItem) async throws -> String
    /// Produce a short (≈3 line) summary of text (typically OCR output).
    func summarize(_ text: String) async throws -> String
}
