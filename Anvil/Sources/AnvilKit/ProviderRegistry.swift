// MARK: - Provider registry (single source of truth; provider list lives here only)

import Foundation

/// Catalog of supported providers. Add a backend here once, everywhere else reads `ProviderRegistry.shared.all`.
@MainActor
public final class ProviderRegistry: ObservableObject {
    public static let shared = ProviderRegistry()
    @Published public var providers: [ProviderDescriptor] = []

    private init() {
        providers = Self.defaultProviders
    }

    public func provider(id: String) -> ProviderDescriptor? {
        providers.first { $0.id == id }
    }

    public var `default`: ProviderDescriptor {
        providers.first { $0.id == "opencode" } ?? providers[0]
    }

    private static let defaultProviders: [ProviderDescriptor] = [
        ProviderDescriptor(id: "opencode", name: "OpenCode", baseURL: nil,
                           requiresAPIKey: false, supportsTools: true, supportsReasoning: true,
                           supportsVision: true, isLocal: true, freeOnly: true),
        ProviderDescriptor(id: "openai", name: "OpenAI", baseURL: "https://api.openai.com/v1",
                           requiresAPIKey: true, supportsTools: true, supportsReasoning: true,
                           supportsVision: true, isLocal: false, freeOnly: false),
        ProviderDescriptor(id: "anthropic", name: "Anthropic", baseURL: "https://api.anthropic.com/v1",
                           requiresAPIKey: true, supportsTools: true, supportsReasoning: true,
                           supportsVision: true, isLocal: false, freeOnly: false),
        ProviderDescriptor(id: "openrouter", name: "OpenRouter", baseURL: "https://openrouter.ai/api/v1",
                           requiresAPIKey: true, supportsTools: true, supportsReasoning: true,
                           supportsVision: true, isLocal: false, freeOnly: false),
        ProviderDescriptor(id: "nvidia-nim", name: "NVIDIA NIM", baseURL: "https://integrate.api.nvidia.com/v1",
                           requiresAPIKey: true, supportsTools: true, supportsReasoning: true,
                           supportsVision: true, isLocal: false, freeOnly: false),
        ProviderDescriptor(id: "google-gemini", name: "Google Gemini", baseURL: "https://generativelanguage.googleapis.com/v1beta",
                           requiresAPIKey: true, supportsTools: true, supportsReasoning: true,
                           supportsVision: true, isLocal: false, freeOnly: false),
        ProviderDescriptor(id: "apple-foundation", name: "Apple Foundation Models", baseURL: nil,
                           requiresAPIKey: false, supportsTools: false, supportsReasoning: true,
                           supportsVision: true, isLocal: true, freeOnly: true),
        ProviderDescriptor(id: "ollama", name: "Ollama (Local)", baseURL: "http://127.0.0.1:11434",
                           requiresAPIKey: false, supportsTools: true, supportsReasoning: false,
                           supportsVision: true, isLocal: true, freeOnly: true),
        ProviderDescriptor(id: "lm-studio", name: "LM Studio / Custom", baseURL: "http://127.0.0.1:1234/v1",
                           requiresAPIKey: false, supportsTools: true, supportsReasoning: false,
                           supportsVision: false, isLocal: true, freeOnly: true),
    ]
}
