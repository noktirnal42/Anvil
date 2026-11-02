// MARK: - Domain models (SwiftData-backed)

import Foundation
import SwiftData

@Model
public final class Session {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var provider: String        // provider id (opencode, openai, anthropic, ...)
    public var model: String           // selected model id
    public var isPinned: Bool
    public var isArchived: Bool

    public var messages: [Message] = []

    public init(id: UUID = UUID(), title: String = "New Session", createdAt: Date = .now,
                updatedAt: Date = .now, provider: String = "opencode", model: String = "",
                isPinned: Bool = false, isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provider = provider
        self.model = model
        self.isPinned = isPinned
        self.isArchived = isArchived
    }
}

@Model
public final class Message {
    public var id: UUID
    public var role: String             // "user" | "assistant" | "tool"
    public var content: String
    public var createdAt: Date
    public var toolCallId: String?
    public var toolName: String?
    public var toolArguments: String?
    public var isStreaming: Bool
    public var isComplete: Bool

    public var session: Session?

    public init(id: UUID = UUID(), role: String, content: String = "",
                createdAt: Date = .now, toolCallId: String? = nil,
                toolName: String? = nil, toolArguments: String? = nil,
                isStreaming: Bool = false, isComplete: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.toolArguments = toolArguments
        self.isStreaming = isStreaming
        self.isComplete = isComplete
    }
}

/// Provider registry entry — single source of truth (System5 lesson #7).
public struct ProviderDescriptor: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let baseURL: String?
    public let requiresAPIKey: Bool
    public let supportsTools: Bool
    public let supportsReasoning: Bool
    public let supportsVision: Bool
    public let isLocal: Bool
    public let freeOnly: Bool

    public init(id: String, name: String, baseURL: String? = nil,
                requiresAPIKey: Bool = true, supportsTools: Bool = true,
                supportsReasoning: Bool = true, supportsVision: Bool = true,
                isLocal: Bool = false, freeOnly: Bool = false) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.requiresAPIKey = requiresAPIKey
        self.supportsTools = supportsTools
        self.supportsReasoning = supportsReasoning
        self.supportsVision = supportsVision
        self.isLocal = isLocal
        self.freeOnly = freeOnly
    }
}

public struct ModelDescriptor: Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let providerId: String
    public let contextWindow: Int?
    public let inputPricePerM: Double?
    public let outputPricePerM: Double?
    public let releasedAt: Date?
    public let isFree: Bool
    public let isLocal: Bool
    public let tags: [String]            // reasoning / tool / vision / local / free

    public init(id: String, name: String, providerId: String,
                contextWindow: Int? = nil, inputPricePerM: Double? = nil,
                outputPricePerM: Double? = nil, releasedAt: Date? = nil,
                isFree: Bool = false, isLocal: Bool = false, tags: [String] = []) {
        self.id = id
        self.name = name
        self.providerId = providerId
        self.contextWindow = contextWindow
        self.inputPricePerM = inputPricePerM
        self.outputPricePerM = outputPricePerM
        self.releasedAt = releasedAt
        self.isFree = isFree
        self.isLocal = isLocal
        self.tags = tags
    }
}
