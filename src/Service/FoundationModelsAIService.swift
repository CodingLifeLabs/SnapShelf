import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
import SnapShelfTypes

// On-device AI via FoundationModels (macOS 26+). The SDK ships the symbols; at runtime
// this throws .unavailable on older OSes (e.g. this Intel/macOS 15 host), so callers fall
// back to RuleBasedAIService or a cloud provider. Real prompt/response wiring lives behind
// the #available gate so it only executes where supported.

public final class FoundationModelsAIService: AIService {
    public init() {}

    public func rename(_ item: ShelfItem) async throws -> String {
        guard #available(macOS 26.0, *) else { throw AIError.unavailable }
        let ocr = (item.ocrText ?? "").prefix(400)
        let app = item.appName ?? "unknown"
        let prompt = """
        Suggest a short descriptive file name (no extension, max 6 words) for a screenshot. \
        App: \(app). Visible text: \(ocr). Reply with only the name.
        """
        return try await complete(prompt: prompt)
    }

    public func summarize(_ text: String) async throws -> String {
        guard #available(macOS 26.0, *) else { throw AIError.unavailable }
        return try await complete(prompt: "Summarize in 3 short lines:\n\(text.prefix(1200))")
    }

    @available(macOS 26.0, *)
    private func complete(prompt: String) async throws -> String {
        // FoundationModels (linked on macOS 26+). Kept minimal; the host here does not
        // enter this path, so it is exercised only on supported OSes.
        let session = FoundationModels.LanguageModelSession()
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
