import Foundation

// Sprint 4: AI provider configuration (opt-in). Keys live in Keychain (SecretStore).

public enum AIProvider: String, Sendable, Codable, CaseIterable, Equatable {
    case foundationModels  // on-device (macOS 26+)
    case openAI
    case claude
    case gemini
    case ollama             // local server
}

public struct AIProviderConfig: Sendable, Equatable, Codable {
    public var provider: AIProvider
    public var model: String
    public var endpoint: URL?
    public var enabled: Bool

    public init(
        provider: AIProvider = .foundationModels,
        model: String = "",
        endpoint: URL? = nil,
        enabled: Bool = false
    ) {
        self.provider = provider
        self.model = model
        self.endpoint = endpoint
        self.enabled = enabled
    }

    /// Default config: AI off, would prefer on-device if enabled.
    public static let `default` = AIProviderConfig()
}
