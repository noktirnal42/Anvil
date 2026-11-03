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

    private let session = URLSession(configuration: .default)

    public func stream(messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        // The adapter is stateless regarding the endpoint — the caller
        // (NativeSessionEngine) must have set the baseURL via configure.
        // For now we read from the first tool-calling-capable provider's
        // baseURL; in v2.0 phase 2 the engine passes the endpoint per call.
        fatalError("Use stream(to:messages:) with an explicit endpoint.")
    }

    /// Stream against an explicit endpoint (baseURL + model + API key).
    public func stream(to baseURL: String, model: String, apiKey: String?,
                       messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        guard let url = URL(string: baseURL.hasSuffix("/") ? baseURL + "chat/completions"
                                                        : baseURL + "/chat/completions") else {
            return StreamResult()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": messages.map { msg in
                var entry: [String: Any] = ["role": msg.role, "content": msg.content]
                if let toolCallId = msg.toolCallId {
                    entry["tool_call_id"] = toolCallId
                }
                return entry
            }
        ]
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
                print("[Anvil] OpenAI-compatible HTTP \(http.statusCode)")
                return StreamResult(text: text, toolCalls: toolCalls)
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
            print("[Anvil] OpenAI-compatible stream error: \(error)")
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
        return StreamResult(text: text, toolCalls: toolCalls)
    }

    public func listModels() async -> [ModelDescriptor] {
        // Implemented per provider in v2.0 phase 2 (fetch /v1/models).
        []
    }

    // MARK: - Helpers (internal, used by engine wiring)

    /// Convenience: stream against a ProviderDescriptor + session model,
    /// resolving the API key from Keychain.
    public func stream(descriptor: ProviderDescriptor, model: String,
                       messages: [ProviderMessage],
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
                            messages: messages,
                            onTextDelta: onTextDelta,
                            onToolCalls: onToolCalls)
    }
}
