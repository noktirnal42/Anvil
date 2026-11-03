// MARK: - Native engine: OpenAICompatibleAdapter (v2.0)

// Covers every provider that exposes an OpenAI-compatible
// POST /chat/completions (SSE) endpoint:
//   OpenCode, OpenAI, OpenRouter, NVIDIA NIM, LM Studio, Ollama
// API keys are read from KeychainStore when the provider requires one.

import Foundation

@MainActor
public final class OpenAICompatibleAdapter: NSObject, ProviderAdapter {
    public static let shared = OpenAICompatibleAdapter()
    private override init() {}

    public let id = "openai-compatible"
    public let name = "OpenAI-Compatible"
    public let capabilities = ProviderCapabilities(supportsTools: true,
                                                   supportsStreaming: true,
                                                   supportsSystemPrompt: true)

    /// Internal so tests can route requests through a mock URLProtocol.
    var session = URLSession(configuration: .default)

    /// The endpoint is chosen per call, so a bare `stream(messages:)` has no
    /// destination. Return an empty result rather than crashing the app.
    public func stream(messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        print("[Anvil] OpenAI-compatible stream needs an explicit endpoint; use stream(to:)")
        return StreamResult()
    }

    /// Stream against an explicit endpoint (baseURL + model + API key).
    public func stream(to baseURL: String, model: String, apiKey: String?,
                       messages: [ProviderMessage], tools: [MCPTool] = [],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        guard let url = URL(string: baseURL.hasSuffix("/") ? baseURL + "chat/completions"
                                                        : baseURL + "/chat/completions") else {
            return StreamResult(error: "Invalid endpoint URL: \(baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": Self.encodeMessages(messages)
        ]
        if !tools.isEmpty {
            body["tools"] = Self.encodeTools(tools)
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        var text = ""
        var toolCalls: [ToolCall] = []

        struct Delta {
            var content = ""
            var toolCalls: [Int: PartialToolCall] = [:]
        }
        struct PartialToolCall {
            var id: String?
            var name: String?
            var arguments = ""
        }
        var delta = Delta()

        do {
            let (bytes, response) = try await session.bytes(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                // Providers usually explain the failure in the body (bad key, unknown model).
                var detail = ""
                for try await line in bytes.lines {
                    detail += line
                    if detail.count > 300 { break }
                }
                let message = "HTTP \(http.statusCode)"
                    + (detail.isEmpty ? "" : ": \(String(detail.prefix(300)))")
                return StreamResult(text: text, toolCalls: toolCalls, error: message)
            }
            for try await line in bytes.lines {
                try Task.checkCancellation()
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("data: ") else { continue }
                let payload = String(trimmed.dropFirst(6))
                guard payload != "[DONE]" else { continue }
                guard let pd = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: pd) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let chunkDelta = choices.first?["delta"] as? [String: Any] else { continue }

                if let content = chunkDelta["content"] as? String, !content.isEmpty {
                    delta.content += content
                    text += content
                    onTextDelta(content)
                }

                if let tcArray = chunkDelta["tool_calls"] as? [[String: Any]] {
                    for tc in tcArray {
                        guard let index = tc["index"] as? Int else { continue }
                        var partial = delta.toolCalls[index] ?? PartialToolCall()
                        if let id = tc["id"] as? String, partial.id == nil {
                            partial.id = id
                        }
                        if let fn = tc["function"] as? [String: Any] {
                            if let name = fn["name"] as? String {
                                partial.name = name
                            }
                            if let args = fn["arguments"] as? String {
                                partial.arguments += args
                            }
                        }
                        delta.toolCalls[index] = partial
                    }
                }
            }
        } catch is CancellationError {
            return StreamResult(text: text, toolCalls: toolCalls)
        } catch {
            return StreamResult(text: text, toolCalls: toolCalls,
                                error: "Connection failed: \(error.localizedDescription)")
        }

        // Finalize buffered tool calls
        let calls = delta.toolCalls.values.compactMap { partial -> ToolCall? in
            guard let id = partial.id, let name = partial.name else { return nil }
            let args = try? JSONSerialization.jsonObject(
                with: partial.arguments.data(using: .utf8) ?? Data(),
                options: []) as? [String: Any]
            return ToolCall(id: id, name: name, arguments: args)
        }
        toolCalls = calls
        if !toolCalls.isEmpty {
            onToolCalls(toolCalls)
        }
        return StreamResult(text: text, toolCalls: toolCalls)
    }

    public func listModels() async -> [ModelDescriptor] {
        // The protocol method has no endpoint; use listModels(for:) instead.
        []
    }

    /// Fetches GET {baseURL}/models. Returns an empty list on any failure so the
    /// picker can fall back to manual model entry.
    public func listModels(for descriptor: ProviderDescriptor) async -> [ModelDescriptor] {
        guard let base = descriptor.baseURL, !base.isEmpty,
              let url = URL(string: base.hasSuffix("/") ? base + "models" : base + "/models") else {
            return []
        }
        var request = URLRequest(url: url)
        if descriptor.requiresAPIKey,
           let apiKey = try? KeychainStore.shared.get(descriptor.id), !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return []
            }
            return Self.parseModels(data, providerId: descriptor.id)
        } catch {
            return []
        }
    }

    /// Parses the OpenAI-style `{"data": [{"id": ...}]}` model list.
    static func parseModels(_ data: Data, providerId: String) -> [ModelDescriptor] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else {
            return []
        }
        return items.compactMap { item in
            guard let id = item["id"] as? String, !id.isEmpty else { return nil }
            return ModelDescriptor(id: id, name: id, providerId: providerId)
        }
        .sorted { $0.id < $1.id }
    }

    // MARK: - Request encoding (internal, covered by tests)

    /// Encodes engine history into OpenAI chat messages. Consecutive assistant
    /// messages that carry a toolCallId form one assistant turn with a
    /// `tool_calls` array, which the API requires before any tool result.
    static func encodeMessages(_ messages: [ProviderMessage]) -> [[String: Any]] {
        var out: [[String: Any]] = []
        var index = 0
        while index < messages.count {
            let msg = messages[index]
            if msg.role == "assistant", msg.toolCallId != nil {
                var calls: [[String: Any]] = []
                while index < messages.count,
                      messages[index].role == "assistant",
                      messages[index].toolCallId != nil {
                    let call = messages[index]
                    let function: [String: Any] = [
                        "name": call.toolName ?? "",
                        "arguments": jsonString(call.toolArguments ?? [:])
                    ]
                    calls.append(["id": call.toolCallId ?? "", "type": "function", "function": function])
                    index += 1
                }
                out.append(["role": "assistant", "content": "", "tool_calls": calls])
                continue
            }
            if msg.role == "tool" {
                out.append(["role": "tool", "tool_call_id": msg.toolCallId ?? "", "content": msg.content])
            } else {
                out.append(["role": msg.role, "content": msg.content])
            }
            index += 1
        }
        return out
    }

    /// Encodes MCP tools as OpenAI function definitions.
    static func encodeTools(_ tools: [MCPTool]) -> [[String: Any]] {
        tools.map { tool in
            let function: [String: Any] = [
                "name": tool.name,
                "description": tool.description ?? "",
                "parameters": tool.inputSchema ?? ["type": "object", "properties": [String: Any]()]
            ]
            return ["type": "function", "function": function]
        }
    }

    static func jsonString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    // MARK: - Helpers (internal, used by engine wiring)

    /// Convenience: stream against a ProviderDescriptor, resolving the API key
    /// from Keychain. Sends no tool definitions.
    public func stream(descriptor: ProviderDescriptor, model: String,
                       messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        await stream(descriptor: descriptor, model: model, messages: messages, tools: [],
                     onTextDelta: onTextDelta, onToolCalls: onToolCalls)
    }

    /// Stream against a ProviderDescriptor with tool definitions, resolving the
    /// API key from Keychain.
    public func stream(descriptor: ProviderDescriptor, model: String,
                       messages: [ProviderMessage], tools: [MCPTool],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        let baseURL = descriptor.baseURL ?? ""
        let apiKey: String?
        if descriptor.requiresAPIKey {
            apiKey = try? KeychainStore.shared.get(descriptor.id)
        } else {
            apiKey = nil
        }
        return await stream(to: baseURL, model: model, apiKey: apiKey,
                            messages: messages, tools: tools,
                            onTextDelta: onTextDelta,
                            onToolCalls: onToolCalls)
    }
}
