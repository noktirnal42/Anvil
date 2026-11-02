// MARK: - Tool call domain models

import Foundation

/// A single tool invocation requested by the model.
public struct ToolCall: @unchecked Sendable, Equatable {
    public let id: String
    public let name: String
    public let arguments: [String: Any]?
    public let serverId: UUID?
    public let serverName: String?

    public init(id: String = UUID().uuidString,
                name: String, arguments: [String: Any]? = nil,
                serverId: UUID? = nil, serverName: String? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.serverId = serverId
        self.serverName = serverName
    }

    public static func == (lhs: ToolCall, rhs: ToolCall) -> Bool {
        lhs.id == rhs.id
    }
}

/// The result of executing a tool call.
public struct ToolCallResult: Sendable, Equatable {
    public let callId: String
    public let name: String
    public let output: String
    public let isError: Bool

    public init(callId: String, name: String, output: String, isError: Bool = false) {
        self.callId = callId
        self.name = name
        self.output = output
        self.isError = isError
    }
}
