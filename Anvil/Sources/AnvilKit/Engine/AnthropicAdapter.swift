// MARK: - Native engine: AnthropicAdapter (v2.0)

// Anthropic Messages API (https://api.anthropic.com/v1/messages)
// Streaming SSE with content blocks: text + tool_use. Tool definitions use
// input_schema (JSON Schema).

import Foundation

@MainActor
public final class AnthropicAdapter: NSObject, ProviderAdapter {
    public static let shared = AnthropicAdapter()
    private override init() {}

    public let id = "anthropic"
    public let name = "Anthropic"
    public let capabilities = ProviderCapabilities(supportsTools: true,
                                                   supportsStreaming: true,
                                                   supportsSystemPrompt: true)

    private let baseURL = "https://api.anthropic.com/v1/messages"
    /// Internal so tests can route requests through a mock URLProtocol.
    var session = URLSession(configuration: .default)
    private let anthropicVersion = "2023-06-01"

    public func stream(messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        // The endpoint depends on the provider, so a bare call has nowhere to go.
        return StreamResult(error: "Anthropic needs an explicit endpoint; use stream(to:).")
    }

    public func stream(to baseURL: String, model: String, apiKey: String?,
                       messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        // Accept either the API root (…/v1) or the full messages endpoint.
        let root = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        let endpoint = root.hasSuffix("/messages") ? root : root + "/messages"
        guard let url = URL(string: endpoint) else {
            return StreamResult(error: "Invalid endpoint URL: \(baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        // Anthropic authenticates with x-api-key, not a Bearer token.
        if let apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }

        // System text goes in its own field. Only plain user/assistant text is
        // sent: tool turns are not offered on this path yet, so they are skipped.
        var system: String? = nil
        var conversation: [[String: Any]] = []
        for msg in messages {
            if msg.role == "system" {
                system = msg.content
                continue
            }
            guard msg.role == "user" || msg.role == "assistant",
                  msg.toolCallId == nil, !msg.content.isEmpty else { continue }
            conversation.append(["role": msg.role, "content": msg.content])
        }

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "stream": true,
            "messages": conversation
        ]
        if let system { body["system"] = system }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        struct Delta {
            var content = ""
        }
        struct PartialToolCall {
            var id: String?
            var name: String?
            var input = ""
        }
        var text = ""
        var toolCalls: [ToolCall] = []
        var streamDelta = Delta()
        var currentToolCallId: String?
        var currentToolCallName = ""
        var currentToolCallInput = ""

        do {
            let (bytes, response) = try await session.bytes(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
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
                      let type = json["type"] as? String else { continue }

                switch type {
                case "content_block_delta":
                    if let delta = json["delta"] as? [String: Any] {
                        if let t = delta["type"] as? String, t == "text_delta",
                           let content = delta["text"] as? String, !content.isEmpty {
                            streamDelta.content += content
                            text += content
                            onTextDelta(content)
                        }
                        if let t = delta["type"] as? String, t == "input_json_delta",
                           let partial = delta["partial_json"] as? String {
                            currentToolCallInput += partial
                        }
                    }
                case "content_block_start":
                    if let block = json["content_block"] as? [String: Any],
                       block["type"] as? String == "tool_use" {
                        currentToolCallId = block["id"] as? String ?? UUID().uuidString
                        currentToolCallName = block["name"] as? String ?? ""
                        currentToolCallInput = ""
                    }
                case "content_block_stop":
                    if let callId = currentToolCallId, !currentToolCallName.isEmpty {
                        let args = try? JSONSerialization.jsonObject(
                            with: currentToolCallInput.data(using: .utf8) ?? Data(),
                            options: []) as? [String: Any]
                        toolCalls.append(ToolCall(id: callId, name: currentToolCallName,
                                                  arguments: args))
                        currentToolCallId = nil
                        currentToolCallName = ""
                        currentToolCallInput = ""
                    }
                default:
                    break
                }
            }
        } catch is CancellationError {
            return StreamResult(text: text, toolCalls: toolCalls)
        } catch {
            return StreamResult(text: text, toolCalls: toolCalls,
                                error: "Connection failed: \(error.localizedDescription)")
        }

        return StreamResult(text: text, toolCalls: toolCalls)
    }

    // Convenience entry point wired to ProviderDescriptor + Keychain
    public func stream(descriptor: ProviderDescriptor, model: String,
                       messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
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

    public func listModels() async -> [ModelDescriptor] {
        []
    }
}
