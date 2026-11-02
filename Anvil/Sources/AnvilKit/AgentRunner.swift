// MARK: - Agent runner (tool-calling orchestration loop)

// Coordinates the agent loop: stream assistant response, surface tool-call
// approvals, execute approved tools via MCPClient, feed results back, and
// repeat up to 4 rounds before a final synthesis turn.

import Foundation

@MainActor
public final class AgentRunner: ObservableObject {
    public static let shared = AgentRunner()
    private init() {}

    @Published public var isRunning = false
    @Published public var pendingToolCall: ToolCall?
    @Published public var roundText: String = ""

    public enum ToolCallDecision: Sendable {
        case approve
        case deny(String)
    }

    private var decisionContinuation: CheckedContinuation<ToolCallDecision, Never>?

    // MARK: - Entry point

    public func run(session: Session,
                    provider: ProviderDescriptor,
                    userMessage: String,
                    store: SessionStore,
                    onComplete: @escaping () -> Void) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        _ = store.appendMessage(to: session, role: "user",
                                content: userMessage, isComplete: true)

        var history = session.messages.map { msg in
            chatMessage(role: msg.role, content: msg.content)
        }

        let maxToolRounds = 4

        for _ in 0..<maxToolRounds {
            guard !Task.isCancelled else { onComplete(); return }

            let round = await streamRound(session: session, provider: provider,
                                          history: history, store: store)

            history.append(contentsOf: round.messages)

            if round.toolCalls.isEmpty {
                // No tool calls → generation complete
                onComplete()
                return
            }

            // Execute each approved tool call
            for call in round.toolCalls {
                guard !Task.isCancelled else { onComplete(); return }
                let result = await executeToolCall(call: call)
                let resultText = result.isError
                    ? "[tool error] \(result.output)"
                    : result.output
                history.append(toolMessage(callId: call.id, name: call.name,
                                           content: resultText, isError: result.isError))
                _ = store.appendMessage(to: session, role: "tool",
                                        content: resultText,
                                        toolCallId: call.id,
                                        toolName: call.name,
                                        toolArguments: "",
                                        isComplete: true)
            }
        }

        // Exhausted tool rounds → final synthesis turn
        let synth = await streamRound(session: session, provider: provider,
                                      history: history, store: store,
                                      synthesis: true)
        history.append(contentsOf: synth.messages)
        onComplete()
    }

    // MARK: - Single streaming round

    private func streamRound(session: Session, provider: ProviderDescriptor,
                             history: [[String: String]], store: SessionStore,
                             synthesis: Bool = false) async -> (text: String,
                                                                  messages: [[String: String]],
                                                                  toolCalls: [ToolCall]) {
        var text = ""
        var toolCalls: [ToolCall] = []
        var newMessages: [[String: String]] = []

        roundText = ""

        await ChatClient.shared.stream(
            session: session,
            provider: provider,
            messages: history.map { m in
                Message(role: m["role"] ?? "assistant",
                        content: m["content"] ?? "",
                        isStreaming: false, isComplete: true)
            },
            onTextDelta: { [weak self] chunk in
                text += chunk
                Task { @MainActor in
                    self?.roundText = text
                }
            },
            onToolCalls: { calls in
                toolCalls = calls
            },
            onComplete: {}
        )

        if !text.isEmpty {
            newMessages.append(["role": "assistant", "content": text])
        }

        return (text, newMessages, toolCalls)
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
    }

    // MARK: - Helpers

    private func chatMessage(role: String, content: String) -> [String: String] {
        ["role": role, "content": content]
    }

    private func toolMessage(callId: String, name: String, content: String,
                             isError: Bool) -> [String: String] {
        ["role": "tool", "content": content, "tool_call_id": callId]
    }
}
