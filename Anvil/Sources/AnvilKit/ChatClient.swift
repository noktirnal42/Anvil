// MARK: - Streaming chat client (OpenAI-compatible SSE)

import Foundation

/// Streams a chat completion over an OpenAI-compatible /chat/completions (SSE)
/// endpoint. Runs entirely on the main actor so callbacks can safely update
/// SwiftUI state. Callers cancel the enclosing Task to stop the stream.
@MainActor
public final class ChatClient: NSObject {
    public static let shared = ChatClient()
    private override init() {}

    /// A partial delta observed within one SSE chunk.
    private struct Delta {
        var content: String = ""
        // tool call index -> accumulated partial call
        var toolCalls: [Int: PartialToolCall] = [:]
    }

    /// A tool call being assembled across possibly-multiple chunks.
    private struct PartialToolCall {
        var id: String?
        var name: String?
        var arguments: String = ""
    }

    /// Streams a chat completion, calling `onTextDelta` with each text chunk,
    /// `onToolCalls` with the complete set of tool calls once the stream ends,
    /// and `onComplete` when the stream ends. The returned `Task` (from the
    /// caller's enclosing `Task`) can be cancelled to stop the stream.
    public func stream(session: Session,
                       provider: ProviderDescriptor,
                       messages: [Message],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void,
                       onComplete: @escaping () -> Void) async {
        guard let url = URL(string: (provider.baseURL ?? "") + "/chat/completions") else {
            print("[Anvil] Invalid provider URL: \(provider.baseURL ?? "nil")")
            onComplete()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        if provider.requiresAPIKey {
            if let key = try? KeychainStore.shared.get(provider.id) {
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
        }

        let body: [String: Any] = [
            "model": session.model,
            "stream": true,
            "messages": messages.map { msg in
                ["role": msg.role, "content": msg.content]
            }
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        var delta = Delta()

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[Anvil] Provider HTTP \(http.statusCode)")
                onComplete()
                return
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

                // Text content
                if let content = chunkDelta["content"] as? String, !content.isEmpty {
                    delta.content += content
                    onTextDelta(content)
                }

                // Tool calls (may be split across chunks; buffer by index)
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
            // Stream was stopped by the user
            onComplete()
            return
        } catch {
            print("[Anvil] Stream error: \(error)")
        }

        // Finalize buffered tool calls
        let calls = delta.toolCalls.values.compactMap { partial -> ToolCall? in
            guard let id = partial.id, let name = partial.name else { return nil }
            let args = try? JSONSerialization.jsonObject(
                with: partial.arguments.data(using: .utf8) ?? Data(),
                options: []) as? [String: Any]
            return ToolCall(id: id, name: name, arguments: args)
        }
        if !calls.isEmpty {
            onToolCalls(calls)
        }
        onComplete()
    }
}
