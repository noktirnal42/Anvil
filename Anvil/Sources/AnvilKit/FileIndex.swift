// MARK: - File index models (SwiftData)

import Foundation
import SwiftData

@Model
public final class FileRecord {
    public var id: UUID
    public var path: String
    public var name: String
    public var uti: String?
    public var indexedAt: Date

    public init(id: UUID = UUID(), path: String, name: String,
                uti: String? = nil, indexedAt: Date = .now) {
        self.id = id
        self.path = path
        self.name = name
        self.uti = uti
        self.indexedAt = indexedAt
    }
}

@Model
public final class IndexedFolder {
    public var id: UUID
    public var path: String
    public var name: String
    public var addedAt: Date

    public init(id: UUID = UUID(), path: String, name: String, addedAt: Date = .now) {
        self.id = id
        self.path = path
        self.name = name
        self.addedAt = addedAt
    }
}
