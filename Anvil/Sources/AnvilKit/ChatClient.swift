// MARK: - Streaming chat client (OpenAI-compatible SSE)

import Foundation

/// Streams a chat completion over an OpenAI-compatible /chat/completions (SSE)
/// endpoint. Runs entirely on the main actor so callbacks can safely update
/// SwiftUI/SwiftState state. Callers cancel the enclosing Task to stop.
@MainActor
public final class ChatClient: NSObject {
    public static let shared = ChatClient()
    private override init() {}

    /// Streams a chat completion, calling `onDelta` with each text chunk and
    /// `onComplete` when the stream ends. The returned `Task` (from the caller's
    /// enclosing `Task`) can be cancelled to stop the stream.
    public func stream(session: Session,
                       provider: ProviderDescriptor,
                       messages: [Message],
                       onDelta: @escaping (String) -> Void,
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
                      let delta = choices.first?["delta"] as? [String: Any],
                      let content = delta["content"] as? String, !content.isEmpty else { continue }
                onDelta(content)
            }
        } catch is CancellationError {
            // Stream was stopped by the user
            onComplete()
            return
        } catch {
            print("[Anvil] Stream error: \(error)")
        }
        onComplete()
    }
}
