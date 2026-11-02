// MARK: - Artifact domain models (SwiftData)

import Foundation
import SwiftData

@Model
public final class Artifact {
    public var id: UUID
    public var title: String
    public var kind: String            // "code" | "markdown" | "html" | "image"
    public var language: String?       // e.g. "swift", "python"
    public var content: String
    public var version: Int
    public var createdAt: Date
    public var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    public var versions: [ArtifactVersion] = []

    public var sessionId: UUID?        // originating session (optional)

    public var iconName: String {
        switch kind {
        case "html": return "curlybraces.square"
        case "markdown": return "doc.richtext"
        case "image": return "photo"
        default: return "chevron.left.forwardslash.chevron.right"
        }
    }

    public init(id: UUID = UUID(), title: String = "Untitled Artifact",
                kind: String = "code", language: String? = nil,
                content: String = "", version: Int = 1,
                createdAt: Date = .now, updatedAt: Date = .now,
                sessionId: UUID? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.language = language
        self.content = content
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sessionId = sessionId
    }
}

@Model
public final class ArtifactVersion {
    public var id: UUID
    public var content: String
    public var version: Int
    public var createdAt: Date
    public var note: String?

    public init(id: UUID = UUID(), content: String, version: Int,
                createdAt: Date = .now, note: String? = nil) {
        self.id = id
        self.content = content
        self.version = version
        self.createdAt = createdAt
        self.note = note
    }
}
