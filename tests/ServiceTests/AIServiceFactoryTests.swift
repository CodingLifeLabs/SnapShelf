import XCTest
@testable import SnapShelfService
@testable import SnapShelfConfig

final class AIServiceFactoryTests: XCTestCase {

    func test_disabled_returnsRuleBased() {
        let config = AIProviderConfig(provider: .openAI, enabled: false)
        let svc = AIServiceFactory.make(config: config, secrets: MemorySecretStore())
        XCTAssertTrue(svc is RuleBasedAIService)
    }

    func test_enabledFoundationModels_returnsFoundationModels() {
        let config = AIProviderConfig(provider: .foundationModels, enabled: true)
        let svc = AIServiceFactory.make(config: config, secrets: MemorySecretStore())
        XCTAssertTrue(svc is FoundationModelsAIService)
    }

    func test_enabledOpenAI_withKey_returnsHTTP() {
        let secrets = MemorySecretStore()
        secrets.write("openai_api_key", value: "sk-test")
        let config = AIProviderConfig(provider: .openAI, model: "gpt-4o-mini", enabled: true)
        let svc = AIServiceFactory.make(config: config, secrets: secrets)
        XCTAssertTrue(svc is HTTPAIService)
    }

    func test_enabledOpenAI_withoutKey_fallsBackToRuleBased() {
        let config = AIProviderConfig(provider: .openAI, enabled: true)
        let svc = AIServiceFactory.make(config: config, secrets: MemorySecretStore())
        XCTAssertTrue(svc is RuleBasedAIService)
    }

    func test_enabledOllama_returnsHTTP() {
        let config = AIProviderConfig(provider: .ollama, model: "llama3.2", enabled: true)
        let svc = AIServiceFactory.make(config: config, secrets: MemorySecretStore())
        XCTAssertTrue(svc is HTTPAIService)
    }

    func test_enabledClaude_withoutEndpoint_fallsBack() {
        let config = AIProviderConfig(provider: .claude, enabled: true)
        let svc = AIServiceFactory.make(config: config, secrets: MemorySecretStore())
        XCTAssertTrue(svc is RuleBasedAIService)
    }
}
