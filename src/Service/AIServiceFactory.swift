import Foundation
import SnapShelfConfig
import SnapShelfTypes

// Sprint 4: provider selection. Rule-based is the safe fallback whenever AI is off,
// unavailable, or lacks credentials.

public enum OllamaAIService {
    public static let defaultEndpoint = URL(string: "http://localhost:11434/v1/chat/completions")!

    /// OpenAI-compatible Ollama client (no key required).
    public static func make(
        model: String = "llama3.2",
        endpoint: URL? = nil,
        client: HTTPClient = URLSession.shared
    ) -> HTTPAIService {
        HTTPAIService(endpoint: endpoint ?? defaultEndpoint, apiKey: "", model: model, client: client)
    }
}

public enum AIServiceFactory {
    public static func make(config: AIProviderConfig, secrets: SecretStore) -> AIService {
        guard config.enabled else { return RuleBasedAIService() }
        switch config.provider {
        case .foundationModels:
            return FoundationModelsAIService()
        case .openAI:
            let key = secrets.read("openai_api_key")
            guard let key, !key.isEmpty else { return RuleBasedAIService() }
            let endpoint = config.endpoint ?? URL(string: "https://api.openai.com/v1/chat/completions")!
            let model = config.model.isEmpty ? "gpt-4o-mini" : config.model
            return HTTPAIService(endpoint: endpoint, apiKey: key, model: model)
        case .ollama:
            let endpoint = config.endpoint ?? OllamaAIService.defaultEndpoint
            let model = config.model.isEmpty ? "llama3.2" : config.model
            return HTTPAIService(endpoint: endpoint, apiKey: "", model: model)
        case .claude, .gemini:
            // Native clients are future work; route through an OpenAI-compatible gateway if set.
            if let endpoint = config.endpoint {
                let key = secrets.read("\(config.provider.rawValue)_api_key") ?? ""
                return HTTPAIService(endpoint: endpoint, apiKey: key, model: config.model)
            }
            return RuleBasedAIService()
        }
    }
}
