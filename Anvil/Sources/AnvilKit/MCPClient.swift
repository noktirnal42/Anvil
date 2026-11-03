// MARK: - MCP client (Model Context Protocol)

// JSON-RPC 2.0 over stdio (local-command servers) and HTTP (streamable/SSE).

import Foundation

public enum MCPTransport: Sendable, Equatable {
    case stdio(command: String, args: [String])
    case http(url: String)
}

public struct MCPServerConfig: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var transport: MCPTransport
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, transport: MCPTransport, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.transport = transport
        self.isEnabled = isEnabled
    }
}

/// A discovered MCP tool. Identified by UUID (tools are compared by identity,
/// not by value, since input schemas are arbitrary JSON).
public struct MCPTool: Identifiable {
    public let id: UUID
    public let serverId: UUID
    public let serverName: String
    public var name: String
    public var description: String?
    public var inputSchema: [String: Any]?

    public init(id: UUID = UUID(), serverId: UUID, serverName: String,
                name: String, description: String? = nil,
                inputSchema: [String: Any]? = nil) {
        self.id = id
        self.serverId = serverId
        self.serverName = serverName
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

public enum MCPError: Error, Sendable, Equatable {
    case serverNotRunning
    case transportFailed(String)
    case protocolError(String)
    case toolNotFound(String)
    case callFailed(String)
    case decodeFailed(String)
}

/// Sendable wrapper for arbitrary JSON dictionaries. Safe because all MCP
/// state is main-actor isolated, so the wrapped dictionary never crosses
/// actor boundaries.
private struct JSONValue: @unchecked Sendable {
    let value: [String: Any]
}

/// Manages MCP server connections and tool discovery/calls. All state is
/// main-actor isolated (SwiftUI publishes from here).
@MainActor
public final class MCPClient: NSObject, ObservableObject {
    public static let shared = MCPClient()
    private override init() {}

    @Published public var configs: [MCPServerConfig] = []
    @Published public var tools: [MCPTool] = []
    @Published public var connectedServers: Set<UUID> = []

    private var servers: [UUID: MCPServer] = [:]
    private var nextRequestId = 0

    // MARK: - Server config

    public func addServer(_ config: MCPServerConfig) {
        configs.append(config)
        if config.isEnabled {
            connect(server: config)
        }
    }

    public func setEnabled(_ config: MCPServerConfig, enabled: Bool) {
        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index].isEnabled = enabled
        }
        if enabled {
            connect(server: config)
        } else {
            disconnect(serverId: config.id)
        }
    }

    // MARK: - Connect / disconnect

    private func connect(server config: MCPServerConfig) {
        guard servers[config.id] == nil else { return }
        let server = MCPServer(config: config, client: self)
        servers[config.id] = server
        Task {
            await server.connect()
        }
    }

    private func disconnect(serverId: UUID) {
        servers[serverId]?.disconnect()
        servers.removeValue(forKey: serverId)
        connectedServers.remove(serverId)
        tools.removeAll { $0.serverId == serverId }
    }

    // MARK: - Tool discovery

    public func listTools(for serverId: UUID) async -> [MCPTool] {
        guard let server = servers[serverId] else { return [] }
        return await server.listTools()
    }

    public func refreshTools() {
        Task {
            var all: [MCPTool] = []
            for config in configs where config.isEnabled {
                if connectedServers.contains(config.id), let server = servers[config.id] {
                    all += await server.listTools()
                }
            }
            self.tools = all
        }
    }

    // MARK: - Tool call

    /// Call a tool by namespaced name (e.g. "filesystem.read_file"). Looks up
    /// which MCP server provides the tool and forwards the call.
    public func callToolByName(_ namespacedName: String, arguments: [String: Any] = [:]) async -> [String: Any]? {
        let serverId = toolServerMap[namespacedName]
        guard let serverId, let server = servers[serverId] else {
            print("[Anvil MCP] No server provides tool '\(namespacedName)'")
            return nil
        }
        return await server.callTool(name: toolName(from: namespacedName),
                                     arguments: arguments)
    }

    public func callTool(serverId: UUID, toolName: String, arguments: [String: Any] = [:]) async -> [String: Any]? {
        guard let server = servers[serverId] else { return nil }
        return await server.callTool(name: toolName, arguments: arguments)
    }

    /// Strip the server prefix from a namespaced tool name.
    private func toolName(from namespacedName: String) -> String {
        if let dot = namespacedName.firstIndex(of: ".") {
            return String(namespacedName[dot...].dropFirst())
        }
        return namespacedName
    }

    /// Rebuild the tool name → serverId map whenever tools are discovered.
    internal func rebuildToolServerMap() {
        toolServerMap.removeAll()
        for config in configs where config.isEnabled {
            guard let server = servers[config.id] else { continue }
            // We don't store tools per-server here; instead read from published tools.
        }
        for tool in tools {
            toolServerMap[tool.name] = tool.serverId
            // Also register a namespaced variant: serverName.toolName
            if let config = configs.first(where: { $0.id == tool.serverId }) {
                toolServerMap["\(config.name).\(tool.name)"] = tool.serverId
            }
        }
    }

    // tool name → server id
    private var toolServerMap: [String: UUID] = [:]

    internal func nextId() -> Int {
        nextRequestId += 1
        return nextRequestId
    }

    internal func serverConnected(_ id: UUID) {
        connectedServers.insert(id)
    }

    internal func serverDisconnected(_ id: UUID) {
        connectedServers.remove(id)
        tools.removeAll { $0.serverId == id }
    }

    internal func receivedTools(_ id: UUID, _ tools: [MCPTool]) {
        self.tools = (self.tools.filter { $0.serverId != id }) + tools
        rebuildToolServerMap()
    }
}

/// A single MCP server connection. Main-actor isolated so all state (pending
/// JSON-RPC continuations, process handles) is touched on one actor.
@MainActor
private final class MCPServer: NSObject {
    let config: MCPServerConfig
    weak var client: MCPClient?

    private var process: Process?
    private var stdin: FileHandle?
    private var readHandle: FileHandle?
    private var pending: [Int: (Result<[String: Any], Error>) -> Void] = [:]

    init(config: MCPServerConfig, client: MCPClient) {
        self.config = config
        self.client = client
        super.init()
    }

    func connect() async {
        switch config.transport {
        case .stdio(let command, let args):
            connectStdio(command: command, args: args)
        case .http(let url):
            connectHTTP(url: url)
        }
    }

    func disconnect() {
        process?.terminate()
        process = nil
        stdin = nil
        readHandle?.readabilityHandler = nil
        readHandle = nil
        Task { @MainActor in
            self.client?.serverDisconnected(self.config.id)
        }
    }

    // MARK: - stdio transport

    private func connectStdio(command: String, args: [String]) {
        let pipeIn = Pipe()      // parent writes -> child stdin
        let pipeOut = Pipe()     // child stdout -> parent reads
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = args
        process.standardInput = pipeIn
        process.standardOutput = pipeOut
        process.standardError = pipeOut
        self.process = process
        self.stdin = pipeIn.fileHandleForWriting
        self.readHandle = pipeOut.fileHandleForReading

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.client?.serverDisconnected(self?.config.id ?? UUID())
            }
        }

        do {
            try process.run()
        } catch {
            Task { @MainActor in
                self.client?.serverDisconnected(self.config.id)
            }
            return
        }

        Task { @MainActor in
            self.client?.serverConnected(self.config.id)
        }

        readHandle?.readabilityHandler = { [weak self] h in
            let data = h.availableData
            guard !data.isEmpty else { return }
            Task { @MainActor in
                self?.processIncoming(data)
            }
        }

        // Initialize handshake
        Task { @MainActor in
            _ = await self.sendJSONRPC(method: "initialize", params: [
                "protocolVersion": "2024-11-05",
                "capabilities": [:],
                "clientInfo": ["name": "Anvil", "version": "0.1.0"]
            ])
            _ = await self.sendJSONRPC(method: "initialized", params: [:])
            self.client?.refreshTools()
        }
    }

    // MARK: - HTTP transport (stub)

    private func connectHTTP(url: String) {
        Task { @MainActor in
            self.client?.serverConnected(self.config.id)
            self.client?.refreshTools()
        }
    }

    // MARK: - JSON-RPC framing

    private func processIncoming(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let d = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let id = json["id"] as? Int else { continue }

            if let continuation = pending.removeValue(forKey: id) {
                if let error = json["error"] as? [String: Any] {
                    let msg = (error["message"] as? String) ?? "unknown error"
                    continuation(.failure(MCPError.protocolError(msg)))
                } else if let result = json["result"] as? [String: Any] {
                    continuation(.success(result))
                } else {
                    continuation(.failure(MCPError.protocolError("no result/error")))
                }
            }
        }
    }

    private func sendJSONRPC(method: String, params: [String: Any]?) async -> JSONValue? {
        let id = client?.nextId() ?? 0
        return await withCheckedContinuation { continuation in
            pending[id] = { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: JSONValue(value: value))
                case .failure(let error):
                    print("[Anvil MCP] \(error)")
                    continuation.resume(returning: nil)
                }
            }
            var payload: [String: Any] = ["jsonrpc": "2.0", "id": id, "method": method]
            if let params { payload["params"] = params }
            guard let d = try? JSONSerialization.data(withJSONObject: payload),
                  let handle = stdin else {
                pending.removeValue(forKey: id)
                continuation.resume(returning: nil)
                return
            }
            var request = d
            request.append(contentsOf: "\n".utf8)
            handle.write(request)
        }
    }

    // MARK: - Tool discovery / calls

    func listTools() async -> [MCPTool] {
        guard let result = await sendJSONRPC(method: "tools/list", params: nil) else { return [] }
        guard let arr = result.value["tools"] as? [[String: Any]] else { return [] }
        return arr.compactMap { t in
            guard let name = t["name"] as? String else { return nil }
            return MCPTool(serverId: config.id, serverName: config.name, name: name,
                           description: t["description"] as? String,
                           inputSchema: t["inputSchema"] as? [String: Any])
        }
    }

    func callTool(name: String, arguments: [String: Any] = [:]) async -> [String: Any]? {
        await sendJSONRPC(method: "tools/call", params: ["name": name, "arguments": arguments])?.value
    }
}
