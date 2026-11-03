// MARK: - Tests: native engine tool calling (v2.0)

import XCTest
@testable import AnvilKit

// Intercepts OpenAI-compatible requests so tests can inspect the request body
// and script the SSE response without touching the network.
final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody = Data()
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var capturedBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.capturedBody = Self.readBody(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: MockURLProtocol.statusCode,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: MockURLProtocol.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}

// Returns queued results in order and records what the engine sent each turn.
@MainActor
final class ScriptedAdapter: ProviderAdapter {
    let id = "scripted-test"
    let name = "Scripted"
    let capabilities = ProviderCapabilities()

    var script: [StreamResult] = []
    var recordedMessages: [[ProviderMessage]] = []
    var recordedToolCounts: [Int] = []

    private func next(messages: [ProviderMessage], tools: [MCPTool]) -> StreamResult {
        recordedMessages.append(messages)
        recordedToolCounts.append(tools.count)
        return script.isEmpty ? StreamResult(text: "(script exhausted)") : script.removeFirst()
    }

    func stream(messages: [ProviderMessage],
                onTextDelta: @escaping (String) -> Void,
                onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        next(messages: messages, tools: [])
    }

    func stream(descriptor: ProviderDescriptor, model: String,
                messages: [ProviderMessage], tools: [MCPTool],
                onTextDelta: @escaping (String) -> Void,
                onToolCalls: @escaping ([ToolCall]) -> Void) async -> StreamResult {
        next(messages: messages, tools: tools)
    }
}

@MainActor
final class EngineToolCallingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        OpenAICompatibleAdapter.shared.session = URLSession(configuration: config)
        MockURLProtocol.capturedBody = nil
        MockURLProtocol.statusCode = 200
    }

    func testHTTPErrorIsReportedWithProviderDetail() async {
        MockURLProtocol.statusCode = 401
        MockURLProtocol.responseBody = Data("{\"error\":\"bad key\"}".utf8)

        let result = await OpenAICompatibleAdapter.shared.stream(
            to: "https://mock.test/v1", model: "m", apiKey: "wrong",
            messages: [ProviderMessage(role: "user", content: "hi")],
            onTextDelta: { _ in }, onToolCalls: { _ in })

        XCTAssertTrue(result.text.isEmpty)
        XCTAssertNotNil(result.error)
        XCTAssertTrue(result.error?.contains("401") ?? false)
        XCTAssertTrue(result.error?.contains("bad key") ?? false)
    }

    // MARK: - Request encoding

    func testEncodeMessagesGroupsToolCallsBeforeResults() {
        let messages = [
            ProviderMessage(role: "user", content: "hi"),
            ProviderMessage(role: "assistant", content: "", toolCallId: "c1",
                            toolName: "read", toolArguments: ["path": "a"]),
            ProviderMessage(role: "assistant", content: "", toolCallId: "c2",
                            toolName: "list", toolArguments: [:]),
            ProviderMessage(role: "tool", content: "A", toolCallId: "c1"),
            ProviderMessage(role: "tool", content: "B", toolCallId: "c2"),
            ProviderMessage(role: "assistant", content: "done")
        ]

        let encoded = OpenAICompatibleAdapter.encodeMessages(messages)

        XCTAssertEqual(encoded.map { $0["role"] as? String },
                       ["user", "assistant", "tool", "tool", "assistant"])
        let calls = encoded[1]["tool_calls"] as? [[String: Any]]
        XCTAssertEqual(calls?.count, 2)
        XCTAssertEqual(calls?[0]["id"] as? String, "c1")
        XCTAssertEqual((calls?[0]["function"] as? [String: Any])?["arguments"] as? String,
                       "{\"path\":\"a\"}")
        XCTAssertEqual((calls?[1]["function"] as? [String: Any])?["arguments"] as? String, "{}")
        XCTAssertEqual(encoded[2]["tool_call_id"] as? String, "c1")
        XCTAssertEqual(encoded[3]["tool_call_id"] as? String, "c2")
    }

    func testEncodeToolsProducesFunctionDefinitions() {
        let tool = MCPTool(serverId: UUID(), serverName: "fs", name: "read_file",
                           description: "Read a file", inputSchema: ["type": "object"])

        let encoded = OpenAICompatibleAdapter.encodeTools([tool])

        XCTAssertEqual(encoded.count, 1)
        XCTAssertEqual(encoded[0]["type"] as? String, "function")
        let function = encoded[0]["function"] as? [String: Any]
        XCTAssertEqual(function?["name"] as? String, "read_file")
        XCTAssertEqual(function?["description"] as? String, "Read a file")
    }

    // MARK: - Streaming against a mock endpoint

    func testStreamSendsToolsAndParsesToolCall() async {
        MockURLProtocol.responseBody = Data("""
        data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"read_file","arguments":"{\\"path\\":"}}]}}]}

        data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\\"a.txt\\"}"}}]}}]}

        data: [DONE]

        """.utf8)
        let tool = MCPTool(serverId: UUID(), serverName: "fs", name: "read_file",
                           inputSchema: ["type": "object"])

        let result = await OpenAICompatibleAdapter.shared.stream(
            to: "https://mock.test/v1", model: "m", apiKey: "k",
            messages: [ProviderMessage(role: "user", content: "read it")],
            tools: [tool],
            onTextDelta: { _ in }, onToolCalls: { _ in })

        XCTAssertEqual(result.toolCalls.count, 1)
        XCTAssertEqual(result.toolCalls.first?.id, "call_1")
        XCTAssertEqual(result.toolCalls.first?.name, "read_file")
        XCTAssertEqual(result.toolCalls.first?.arguments?["path"] as? String, "a.txt")

        let body = MockURLProtocol.capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertEqual((body?["tools"] as? [[String: Any]])?.count, 1)
    }

    func testStreamOmitsToolsKeyWhenNoToolsAreOffered() async {
        MockURLProtocol.responseBody = Data("""
        data: {"choices":[{"delta":{"content":"Hel"}}]}

        data: {"choices":[{"delta":{"content":"lo"}}]}

        data: [DONE]

        """.utf8)

        let result = await OpenAICompatibleAdapter.shared.stream(
            to: "https://mock.test/v1", model: "m", apiKey: nil,
            messages: [ProviderMessage(role: "user", content: "hi")],
            tools: [],
            onTextDelta: { _ in }, onToolCalls: { _ in })

        XCTAssertEqual(result.text, "Hello")
        XCTAssertTrue(result.toolCalls.isEmpty)
        let body = MockURLProtocol.capturedBody.flatMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
        XCTAssertNil(body?["tools"])
    }

    // MARK: - Engine loop

    func testEngineShowsProviderErrorInTranscriptAndStops() async {
        let adapter = ScriptedAdapter()
        adapter.script = [StreamResult(error: "HTTP 401: bad key")]
        ProviderAdapterRegistry.shared.register(adapter, for: adapter.id)
        let descriptor = ProviderDescriptor(id: adapter.id, name: adapter.name)
        let session = SessionStore.shared.createSession(title: "Error surfacing",
                                                        provider: adapter.id, model: "m")
        let engine = NativeSessionEngine.shared

        var completed = false
        await engine.run(session: session, descriptor: descriptor, model: "m",
                         userMessage: "hello", store: SessionStore.shared,
                         onComplete: { completed = true })

        XCTAssertTrue(completed)
        XCTAssertEqual(adapter.recordedMessages.count, 1, "engine must stop after a provider error")
        XCTAssertEqual(engine.lastError, "HTTP 401: bad key")
        let transcript = session.messages.sorted { $0.createdAt < $1.createdAt }
        XCTAssertEqual(transcript.map(\.role), ["user", "error"])
        XCTAssertEqual(transcript.last?.content, "HTTP 401: bad key")
    }

    func testEngineRecordsToolCallBeforeItsResult() async throws {
        let adapter = ScriptedAdapter()
        adapter.script = [
            StreamResult(text: "", toolCalls: [
                ToolCall(id: "call_9", name: "read_file", arguments: ["path": "x"])
            ]),
            StreamResult(text: "final answer")
        ]
        ProviderAdapterRegistry.shared.register(adapter, for: adapter.id)
        let descriptor = ProviderDescriptor(id: adapter.id, name: adapter.name)
        let session = SessionStore.shared.createSession(title: "Tool loop",
                                                        provider: adapter.id, model: "m")
        let engine = NativeSessionEngine.shared

        let run = Task { @MainActor in
            await engine.run(session: session, descriptor: descriptor, model: "m",
                             userMessage: "read x", store: SessionStore.shared,
                             onComplete: {})
        }
        // Wait for the engine to ask for approval, then approve the call.
        var waited = 0
        while engine.pendingToolCall == nil && waited < 400 {
            try await Task.sleep(nanoseconds: 5_000_000)
            waited += 1
        }
        XCTAssertNotNil(engine.pendingToolCall)
        engine.approveCurrentToolCall()
        await run.value

        // The second model turn must see the assistant call before its result.
        XCTAssertEqual(adapter.recordedMessages.count, 2)
        let secondTurn = adapter.recordedMessages[1]
        XCTAssertEqual(secondTurn.map(\.role), ["user", "assistant", "tool"])
        XCTAssertEqual(secondTurn[1].toolCallId, "call_9")
        XCTAssertEqual(secondTurn[1].toolName, "read_file")
        XCTAssertEqual(secondTurn[1].toolArguments?["path"] as? String, "x")
        XCTAssertEqual(secondTurn[2].toolCallId, "call_9")

        // The persisted transcript keeps the same order.
        let transcript = session.messages.sorted { $0.createdAt < $1.createdAt }
        XCTAssertEqual(transcript.map(\.role), ["user", "assistant", "tool", "assistant"])
        XCTAssertEqual(transcript.last?.content, "final answer")
    }
}
