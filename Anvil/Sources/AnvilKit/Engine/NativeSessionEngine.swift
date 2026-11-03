// MARK: - Native engine: NativeSessionEngine (v2.0)

// Pure-Swift replacement for OpenCodeBridge. Owns conversation history,
// runs the agent tool-calling loop, and delegates inference to a
// ProviderAdapter. No CLI subprocess, no bun, no Node.

import Foundation
import SwiftData

@MainActor
public final class NativeSessionEngine: ObservableObject {
    public static let shared = NativeSessionEngine()
    private init() {}

    /// Whether a generation (including tool rounds) is in flight.
    @Published public var isRunning = false
    /// The assistant's accumulated text for the current round.
    @Published public var roundText: String = ""

    private var currentTask: Task<Void, Never>?
    private var decisionContinuation: CheckedContinuation<ToolCallDecision, Never>?
    public var pendingToolCall: ToolCall?

    private let adapterRegistry = ProviderAdapterRegistry.shared

    /// Maximum model turns that may request tools before the engine forces a
    /// tool-free synthesis answer. Overridable for long agentic tasks.
    public var maxToolRounds = 25

    public enum ToolCallDecision: Sendable {
        case approve
        case deny(String)
    }

    public enum EngineError: LocalizedError, Sendable {
        case noProvider
        case streamCancelled
        case toolExecutionFailed(String)
        public var errorDescription: String? {
            switch self {
            case .noProvider: return "No provider selected for this session."
            case .streamCancelled: return "Stream was cancelled."
            case .toolExecutionFailed(let msg): return "Tool execution failed: \(msg)"
            }
        }
    }

    // MARK: - Entry point

    /// Runs the full agent loop for one user message.
    ///
    /// - Parameters:
    ///   - session: target session (SwiftData-backed)
    ///   - userMessage: the user's input text
    ///   - store: SessionStore for persistence
    ///   - onComplete: called when the full loop finishes
    public func run(session: Session,
                    descriptor: ProviderDescriptor,
                    model: String,
                    userMessage: String,
                    store: SessionStore,
                    onComplete: @escaping () -> Void) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        guard let adapter = adapterRegistry.adapter(for: descriptor.id) else {
            onComplete()
            return
        }

        // Persist the user message
        _ = store.appendMessage(to: session, role: "user", content: userMessage, isComplete: true)

        // Build conversation history fed to the model
        // SwiftData relationships are unordered, so sort before replaying history.
        var history: [ProviderMessage] = session.messages.sorted { $0.createdAt < $1.createdAt }.map { msg in
            ProviderMessage(role: msg.role, content: msg.content,
                            toolCallId: msg.toolCallId, toolName: msg.toolName,
                            toolArguments: msg.toolArguments.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] })
        }

        for _ in 0..<maxToolRounds {
            guard !Task.isCancelled else { onComplete(); return }

            let result = await streamRound(adapter: adapter, descriptor: descriptor,
                                           model: model, history: history,
                                           tools: MCPClient.shared.tools)

            // Append assistant message if there's text
            if !result.text.isEmpty {
                history.append(ProviderMessage(role: "assistant", content: result.text))
                _ = store.appendMessage(to: session, role: "assistant",
                                        content: result.text, isComplete: true)
            }

            // No tool calls → generation complete
            if result.toolCalls.isEmpty {
                onComplete()
                return
            }

            // Record every requested call as an assistant turn before any result,
            // so each tool message has a matching tool_call_id in history.
            for call in result.toolCalls {
                let arguments = call.arguments ?? [:]
                history.append(ProviderMessage(role: "assistant", content: "",
                                               toolCallId: call.id, toolName: call.name,
                                               toolArguments: arguments))
                _ = store.appendMessage(to: session, role: "assistant", content: "",
                                        toolCallId: call.id, toolName: call.name,
                                        toolArguments: Self.argumentsJSON(arguments),
                                        isComplete: true)
            }

            for call in result.toolCalls {
                let resultText: String
                if Task.isCancelled {
                    resultText = "[tool error] cancelled before execution"
                } else {
                    let toolResult: ToolCallResult
                    do {
                        toolResult = try await requestApprovalAndExecute(call: call)
                    } catch {
                        toolResult = ToolCallResult(callId: call.id, name: call.name,
                                                    output: "\(error)", isError: true)
                    }
                    resultText = toolResult.isError
                        ? "[tool error] \(toolResult.output)"
                        : toolResult.output
                }
                history.append(ProviderMessage(role: "tool", content: resultText,
                                               toolCallId: call.id))
                _ = store.appendMessage(to: session, role: "tool",
                                        content: resultText,
                                        toolCallId: call.id,
                                        toolName: call.name)
            }
        }

        // Exhausted tool rounds → final synthesis turn with no tools offered
        roundText = ""
        let synthesis = await streamRound(adapter: adapter, descriptor: descriptor,
                                          model: model, history: history, tools: [])
        if !synthesis.text.isEmpty {
            history.append(ProviderMessage(role: "assistant", content: synthesis.text))
            _ = store.appendMessage(to: session, role: "assistant",
                                    content: synthesis.text, isComplete: true)
        }
        onComplete()
    }

    // MARK: - Single streaming round

    /// Streams one model turn. Text deltas update `roundText` live; the final
    /// text and tool calls come from the adapter's returned StreamResult.
    private func streamRound(adapter: ProviderAdapter, descriptor: ProviderDescriptor,
                             model: String, history: [ProviderMessage],
                             tools: [MCPTool]) async -> StreamResult {
        roundText = ""

        let result = await adapter.stream(descriptor: descriptor, model: model,
                                          messages: history, tools: tools,
                                          onTextDelta: { [weak self] chunk in
                                              Task { @MainActor in
                                                  self?.roundText += chunk
                                              }
                                          },
                                          onToolCalls: { _ in })
        roundText = result.text
        return result
    }

    // MARK: - Tool approval + execution

    private func requestApproval(call: ToolCall) async -> ToolCallDecision {
        await withCheckedContinuation { continuation in
            self.pendingToolCall = call
            self.decisionContinuation = continuation
        }
    }

    public func approveCurrentToolCall() {
        resumeDecision(.approve)
    }

    public func denyCurrentToolCall(reason: String) {
        resumeDecision(.deny(reason))
    }

    private func resumeDecision(_ decision: ToolCallDecision) {
        guard let continuation = decisionContinuation else { return }
        decisionContinuation = nil
        pendingToolCall = nil
        continuation.resume(returning: decision)
    }

    private func requestApprovalAndExecute(call: ToolCall) async throws -> ToolCallResult {
        let decision = await requestApproval(call: call)
        switch decision {
        case .approve:
            return await executeToolCall(call: call)
        case .deny(let reason):
            return ToolCallResult(callId: call.id, name: call.name,
                                  output: "denied by user: \(reason)", isError: true)
        }
    }

    private func executeToolCall(call: ToolCall) async -> ToolCallResult {
        // Route by namespaced name (e.g. "filesystem.read_file") or bare name.
        let output = await MCPClient.shared.callToolByName(call.name,
                                                           arguments: call.arguments ?? [:])
        if let dict = output, let content = dict["content"] as? String {
            return ToolCallResult(callId: call.id, name: call.name, output: content)
        } else {
            return ToolCallResult(callId: call.id, name: call.name,
                                  output: "\(output?.description ?? "no output")",
                                  isError: output == nil)
        }
    }

    /// Serializes tool arguments as the JSON object string stored on messages.
    static func argumentsJSON(_ arguments: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: arguments),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    public func stop() {
        decisionContinuation = nil
        pendingToolCall = nil
        currentTask?.cancel()
        currentTask = nil
    }
}
