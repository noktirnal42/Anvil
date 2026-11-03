// MARK: - Native engine: ProviderAdapter protocol (v2.0)

// Replaces the OpenCodeBridge / ChatClient split with a single Swift-native
// abstraction. Each AI provider conforms to ProviderAdapter; the engine never
// knows which provider it's talking to.

import Foundation

/// A normalized message passed to/from a provider.
public struct ProviderMessage: @unchecked Sendable, Equatable {
    public let role: String          // "system" | "user" | "assistant" | "tool"
    public let content: String
    public let toolCallId: String?   // set for role == "tool"
    public let toolName: String?     // set for role == "assistant" when a tool call follows
    public let toolArguments: [String: Any]?

    public init(role: String, content: String = "", toolCallId: String? = nil,
                toolName: String? = nil, toolArguments: [String: Any]? = nil) {
        self.role = role
        self.content = content
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.toolArguments = toolArguments
    }

    public static func == (lhs: ProviderMessage, rhs: ProviderMessage) -> Bool {
        lhs.role == rhs.role && lhs.content == rhs.content
            && lhs.toolCallId == rhs.toolCallId && lhs.toolName == rhs.toolName
    }
}

/// Capabilities a provider advertises.
public struct ProviderCapabilities: Sendable, Equatable {
    public let supportsTools: Bool
    public let supportsStreaming: Bool
    public let supportsSystemPrompt: Bool
    public let maxContextTokens: Int?

    public init(supportsTools: Bool = true, supportsStreaming: Bool = true,
                supportsSystemPrompt: Bool = true, maxContextTokens: Int? = nil) {
        self.supportsTools = supportsTools
        self.supportsStreaming = supportsStreaming
        self.supportsSystemPrompt = supportsSystemPrompt
        self.maxContextTokens = maxContextTokens
    }
}

/// Result of a streaming turn: accumulated text + any tool calls requested.
public struct StreamResult: Sendable, Equatable {
    public let text: String
    public let toolCalls: [ToolCall]

    public init(text: String = "", toolCalls: [ToolCall] = []) {
        self.text = text
        self.toolCalls = toolCalls
    }
}

/// A single provider. Conformers implement one provider family (e.g. all
/// OpenAI-compatible endpoints share OpenAICompatibleAdapter).
/// Class-bound because adapters are shared singletons (main-actor isolated).
@MainActor
public protocol ProviderAdapter: AnyObject {
    /// Stable provider identifier (matches ProviderDescriptor.id).
    var id: String { get }
    /// Human-readable name.
    var name: String { get }
    /// Capabilities advertised by this provider.
    var capabilities: ProviderCapabilities { get }

    /// Stream a chat completion. Calls `onTextDelta` with each text chunk and
    /// `onToolCalls` once with the full set of tool calls at end of stream.
    /// Caller cancels the enclosing Task to stop mid-stream.
    func stream(messages: [ProviderMessage],
                onTextDelta: @escaping (String) -> Void,
                onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult

    /// Stream against a specific provider descriptor (resolves baseURL, model,
    /// and API key from Keychain). Default implementation calls
    /// `stream(to:model:apiKey:onTextDelta:onToolCalls:)`.
    func stream(descriptor: ProviderDescriptor, model: String,
                messages: [ProviderMessage],
                onTextDelta: @escaping (String) -> Void,
                onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult

    /// Optional: fetch the model catalog for this provider.
    func listModels() async -> [ModelDescriptor]
}

// Default: listModels returns empty (provider may not expose a catalog).
extension ProviderAdapter {
    public func listModels() async -> [ModelDescriptor] { [] }

    public func stream(descriptor: ProviderDescriptor, model: String,
                       messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        // Base default: no endpoint knowledge; subclasses override.
        return StreamResult()
    }
}
