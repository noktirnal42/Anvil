# Anvil v2.0 — Native Swift Engine

## Goal
Replace the `OpenCodeBridge` (shells out to MIT opencode CLI) with a **pure-Swift session engine** so Anvil has zero external CLI dependency. All inference, tool orchestration, and session management run natively in Swift.

## Architecture

```
NativeSessionEngine (replaces OpenCodeBridge)
├── ProviderAdapter (protocol)
│   ├── OpenAICompatibleAdapter  (OpenCode, OpenAI, OpenRouter, NVIDIA NIM, LM Studio, Ollama)
│   ├── AnthropicAdapter
│   ├── GoogleGeminiAdapter
│   └── AppleFoundationAdapter
├── ToolExecutor (runs MCP tools natively — reuses MCPClient)
├── MessageStream (URLSession SSE → ProviderMessage deltas)
└── SessionStore (SwiftData persistence — already exists, reused)
```

## ProviderAdapter protocol
```swift
@MainActor
protocol ProviderAdapter {
    var id: String { get }
    var name: String { get }
    var supportsTools: Bool { get }
    var supportsStreaming: Bool { get }
    func stream(messages: [ProviderMessage], onDelta: @escaping (String) -> Void,
                onToolCalls: @escaping ([ToolCall]) -> Void, onComplete: @escaping () -> Void) async
}
```

## NativeSessionEngine responsibilities
- Own the conversation history (SwiftData-backed via SessionStore)
- Run the agent loop: stream assistant → collect tool calls → approve → execute → feed back → repeat (max 4 rounds) → synthesis
- Start/stop generation, cancel in-flight streams
- No CLI subprocess, no bun, no Node

## Migration path
- v1: `OpenCodeBridge` spawns `opencode-cli serve` subprocess
- v2: `NativeSessionEngine` speaks providers directly via URLSession
- `ChatClient` SSE logic absorbed into `NativeSessionEngine` / provider adapters
- `OpenCodeBridge` removed once all providers have native adapters

## Phase 1 (this branch)
1. `ProviderAdapter` protocol + `NativeSessionEngine` core
2. `OpenAICompatibleAdapter` (covers OpenCode, OpenAI, OpenRouter, NVIDIA NIM, LM Studio, Ollama)
3. Wire `ChatView` to use `NativeSessionEngine` instead of `ChatClient` directly
4. Build + test; `OpenCodeBridge` remains but unused

## Phase 2 (follow-up)
5. `AnthropicAdapter`, `GoogleGeminiAdapter`, `AppleFoundationAdapter`
6. Remove `OpenCodeBridge`, `ChatClient` (fully replaced)
7. Native tool execution without MCP dependency where possible
