// MARK: - Native engine: ProviderAdapterRegistry (v2.0)

// Maps ProviderRegistry descriptors to ProviderAdapter instances.
// OpenAICompatibleAdapter covers OpenCode, OpenAI, OpenRouter, NVIDIA NIM,
// LM Studio, and Ollama (all OpenAI-compatible /chat/completions SSE).

import Foundation

@MainActor
public final class ProviderAdapterRegistry: ObservableObject {
    public static let shared = ProviderAdapterRegistry()
    private init() {}

    private var adapters: [String: ProviderAdapter] = [:]

    public func register(_ adapter: ProviderAdapter, for providerId: String) {
        adapters[providerId] = adapter
    }

    public func adapter(for providerId: String) -> ProviderAdapter? {
        adapters[providerId]
    }

    public func registerDefaults() {
        let openAICompatible = OpenAICompatibleAdapter.shared
        // OpenAI-compatible providers
        for id in ["openai", "openrouter", "nvidia-nim", "lm-studio", "ollama"] {
            register(openAICompatible, for: id)
        }
        // OpenCode's embedded server speaks OpenAI-compatible /chat/completions
        register(openAICompatible, for: "opencode")
        // TODO (v2.0 phase 2): AnthropicAdapter, GoogleGeminiAdapter,
        // AppleFoundationAdapter
    }
}
