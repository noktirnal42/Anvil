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

    /// The active provider adapter. Set by the UI when a session's provider
    /// is chosen; defaults to the OpenCode-compatible adapter.
    public var adapter: ProviderAdapter?

    private var currentTask: Task<Void, Never>?
    private var decisionContinuation: CheckedContinuation<ToolCallDecision, Never>?
    public var pendingToolCall: ToolCall?

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
                    userMessage: String,
                    store: SessionStore,
                    onComplete: @escaping () -> Void) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        guard let adapter else {
            onComplete()
            return
        }

        // Persist the user message
        _ = store.appendMessage(to: session, role: "user", content: userMessage, isComplete: true)

        // Build conversation history fed to the model
        var history: [ProviderMessage] = session.messages.map { msg in
            ProviderMessage(role: msg.role, content: msg.content,
                            toolCallId: msg.toolCallId, toolName: msg.toolName,
                            toolArguments: msg.toolArguments.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] })
        }

        let maxToolRounds = 4

        for _ in 0..<maxToolRounds {
            guard !Task.isCancelled else { onComplete(); return }

            roundText = ""
            let result = await streamRound(adapter: adapter, history: history, store: store)

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

            // Execute each approved tool call
            for call in result.toolCalls {
                guard !Task.isCancelled else { onComplete(); return }

                let toolResult: ToolCallResult
                do {
                    toolResult = try await requestApprovalAndExecute(call: call)
                } catch {
                    toolResult = ToolCallResult(callId: call.id, name: call.name,
                                                output: "\(error)", isError: true)
                }

                let resultText = toolResult.isError
                    ? "[tool error] \(toolResult.output)"
                    : toolResult.output
                history.append(ProviderMessage(role: "tool", content: resultText,
                                               toolCallId: call.id))
                _ = store.appendMessage(to: session, role: "tool",
                                        content: resultText,
                                        toolCallId: call.id,
                                        toolName: call.name,
                                        toolArguments: "")
            }
        }

        // Exhausted tool rounds → final synthesis turn (no tools)
        roundText = ""
        let synthesis = await streamRound(adapter: adapter, history: history, store: store,
                                          synthesis: true)
        if !synthesis.text.isEmpty {
            history.append(ProviderMessage(role: "assistant", content: synthesis.text))
            _ = store.appendMessage(to: session, role: "assistant",
                                    content: synthesis.text, isComplete: true)
        }
        onComplete()
    }

    // MARK: - Single streaming round

    private func streamRound(adapter: ProviderAdapter, history: [ProviderMessage],
                             store: SessionStore, synthesis: Bool = false)
        async -> StreamResult {
        var text = ""
        var toolCalls: [ToolCall] = []

        roundText = ""

        await adapter.stream(messages: history,
                             onTextDelta: { [weak self] chunk in
                                 text += chunk
                                 Task { @MainActor in
                                     self?.roundText = text
                                 }
                             },
                             onToolCalls: { calls in
                                 toolCalls = calls
                             })

        return StreamResult(text: text, toolCalls: toolCalls)
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
        guard let serverId = call.serverId else {
            return ToolCallResult(callId: call.id, name: call.name,
                                  output: "no MCP server bound to tool", isError: true)
        }
        let output = await MCPClient.shared.callTool(
            serverId: serverId, toolName: call.name, arguments: call.arguments ?? [:])
        if let dict = output, let content = dict["content"] as? String {
            return ToolCallResult(callId: call.id, name: call.name, output: content)
        } else {
            return ToolCallResult(callId: call.id, name: call.name,
                                  output: "\(output?.description ?? "no output")",
                                  isError: output == nil)
        }
    }

    public func stop() {
        decisionContinuation = nil
        pendingToolCall = nil
        currentTask?.cancel()
        currentTask = nil
    }
}
