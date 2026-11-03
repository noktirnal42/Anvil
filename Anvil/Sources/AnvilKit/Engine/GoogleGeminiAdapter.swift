// MARK: - Native engine: GoogleGeminiAdapter (v2.0)

// Google Gemini API (https://generativelanguage.googleapis.com/v1beta)
// Streaming generateContent with function calling.

import Foundation

@MainActor
public final class GoogleGeminiAdapter: NSObject, ProviderAdapter {
    public static let shared = GoogleGeminiAdapter()
    private override init() {}

    public let id = "google-gemini"
    public let name = "Google Gemini"
    public let capabilities = ProviderCapabilities(supportsTools: true,
                                                   supportsStreaming: true,
                                                   supportsSystemPrompt: false)

    private let session = URLSession(configuration: .default)

    public func stream(messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        fatalError("Use stream(to:model:apiKey:) with explicit credentials.")
    }

    public func stream(to baseURL: String, model: String, apiKey: String?,
                       messages: [ProviderMessage],
                       onTextDelta: @escaping (String) -> Void,
                       onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        // Gemini expects the API key as a query parameter and the model in the path.
        let keyParam = apiKey.map { "?key=\($0)" } ?? ""
        let urlString = "\(baseURL)\(keyParam)"
        guard let url = URL(string: urlString) else { return StreamResult() }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Convert messages to Gemini contents
        var contents: [[String: Any]] = []
        var systemInstruction: [String: Any]?
        for msg in messages {
            if msg.role == "system" {
                systemInstruction = [
                    "parts": [["text": msg.content]]
                ]
            } else {
                var role = msg.role
                if role == "tool" { role = "function" }
                contents.append([
                    "role": role,
                    "parts": [["text": msg.content]]
                ])
            }
        }

        var body: [String: Any] = [
            "contents": contents,
            "generationConfig": ["temperature": 0.7]
        ]
        if let systemInstruction { body["systemInstruction"] = systemInstruction }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        var text = ""
        var toolCalls: [ToolCall] = []

        do {
            let (bytes, response) = try await session.bytes(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                print("[Anvil] Gemini HTTP \(http.statusCode)")
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
                      let candidates = json["candidates"] as? [[String: Any]],
                      let first = candidates.first,
                      let content = first["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]] else { continue }

                for part in parts {
                    if let t = part["text"] as? String, !t.isEmpty {
                        text += t
                        onTextDelta(t)
                    }
                    if let fc = part["functionCall"] as? [String: Any],
                       let name = fc["name"] as? String {
                        let args = (fc["args"] as? [String: Any]) ?? [:]
                        toolCalls.append(ToolCall(id: UUID().uuidString, name: name, arguments: args))
                    }
                }
            }
        } catch is CancellationError {
            return StreamResult(text: text, toolCalls: toolCalls)
        } catch {
            print("[Anvil] Gemini stream error: \(error)")
        }

        return StreamResult(text: text, toolCalls: toolCalls)
    }

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
        return await stream(to: descriptor.baseURL ?? "",
                            model: model, apiKey: apiKey,
                            messages: messages,
                            onTextDelta: onTextDelta,
                            onToolCalls: onToolCalls)
    }

    public func listModels() async -> [ModelDescriptor] { [] }
}
