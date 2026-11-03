// MARK: - Native engine: AppleFoundationAdapter (v2.0)

// Apple Foundation Models framework (on-device + Private Cloud Compute).
// Available on macOS 15+/iOS 18+. Uses LLMModelSession for local inference.
// Tool calling support depends on the model; this adapter exposes whatever
// the session reports.

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
public final class AppleFoundationAdapter: NSObject, ProviderAdapter {
    public static let shared = AppleFoundationAdapter()
    private override init() {}

    public let id = "apple-foundation"
    public let name = "Apple Foundation Models"
    public let capabilities = ProviderCapabilities(supportsTools: false,
                                                   supportsStreaming: true,
                                                   supportsSystemPrompt: true,
                                                   maxContextTokens: nil)

    public func stream(messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        // Foundation Models uses a different API shape (LLMModelSession.respond).
        // Kept as a stub for now; full integration in v2.0 phase 2.
        return StreamResult()
    }

    public func stream(to baseURL: String, model: String, apiKey: String?,
                       messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        // Apple Foundation Models is local; baseURL/apiKey are unused.
        return await stream(messages: messages,
                            onTextDelta: onTextDelta,
                            onToolCalls: onToolCalls)
    }

    public func stream(descriptor: ProviderDescriptor, model: String,
                       messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        return await stream(messages: messages,
                            onTextDelta: onTextDelta,
                            onToolCalls: onToolCalls)
    }

    public func listModels() async -> [ModelDescriptor] {
        []
    }
}
