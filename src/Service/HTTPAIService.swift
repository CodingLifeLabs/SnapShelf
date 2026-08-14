import Foundation
import SnapShelfTypes

// Sprint 4: OpenAI-compatible chat-completions client (covers OpenAI + Ollama + any
// compatible gateway). The HTTP transport is injectable so it is testable without keys.

public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {}

public final class HTTPAIService: AIService {
    private let endpoint: URL
    private let apiKey: String
    private let model: String
    private let client: HTTPClient

    public init(endpoint: URL, apiKey: String, model: String, client: HTTPClient = URLSession.shared) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.client = client
    }

    public func rename(_ item: ShelfItem) async throws -> String {
        let ocr = (item.ocrText ?? "").prefix(400)
        let app = item.appName ?? "unknown"
        let prompt = """
        Suggest a short, descriptive file name (no extension, no quotes, max 6 words) \
        for a screenshot. App: \(app). Visible text: \(ocr). Reply with only the name.
        """
        return try await complete(prompt: prompt)
    }

    public func summarize(_ text: String) async throws -> String {
        try await complete(prompt: "Summarize in 3 short bullet lines:\n\(text.prefix(1200))")
    }

    private func complete(prompt: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": prompt]],
            "temperature": 0.2,
            "max_tokens": 120
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, urlResponse) = try await client.data(for: request)
        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(statusCode) else {
            throw AIError.requestFailed("HTTP \(statusCode)")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.decodeFailed("missing choices[0].message.content")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
