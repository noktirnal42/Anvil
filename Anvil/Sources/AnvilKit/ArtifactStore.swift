// MARK: - Artifact store

import Foundation
import SwiftData

@MainActor
public final class ArtifactStore: ObservableObject {
    public static let shared = ArtifactStore()
    public let context: ModelContext

    @Published public var artifacts: [Artifact] = []
    @Published public var selectedArtifact: Artifact?

    private init() {
        self.context = SwiftDataStack.shared.mainContext
        loadArtifacts()
    }

    // MARK: - CRUD

    public func loadArtifacts() {
        let descriptor = FetchDescriptor<Artifact>(
            sortBy: [SortDescriptor(\Artifact.updatedAt, order: .reverse)]
        )
        if let fetched = try? context.fetch(descriptor) {
            artifacts = fetched
        }
    }

    public func createArtifact(title: String, kind: String, language: String?,
                               content: String, sessionId: UUID? = nil) -> Artifact {
        let artifact = Artifact(title: title, kind: kind, language: language,
                                content: content, version: 1, sessionId: sessionId)
        let version = ArtifactVersion(content: content, version: 1)
        artifact.versions.append(version)
        context.insert(artifact)
        save()
        loadArtifacts()
        selectedArtifact = artifact
        return artifact
    }

    public func updateArtifact(_ artifact: Artifact, content: String,
                               title: String? = nil, note: String? = nil) {
        let nextVersion = artifact.version + 1
        artifact.content = content
        artifact.version = nextVersion
        artifact.updatedAt = .now
        if let title { artifact.title = title }

        let version = ArtifactVersion(content: content, version: nextVersion, note: note)
        artifact.versions.append(version)

        save()
        loadArtifacts()
    }

    public func deleteArtifact(_ artifact: Artifact) {
        if selectedArtifact?.id == artifact.id {
            selectedArtifact = artifacts.first { $0.id != artifact.id }
        }
        context.delete(artifact)
        save()
        loadArtifacts()
    }

    // MARK: - Export

    public func exportArtifact(_ artifact: Artifact, to url: URL) throws {
        let data: Data
        switch artifact.kind {
        case "html":
            data = artifact.content.data(using: .utf8) ?? Data()
        case "image":
            // placeholder: write content as-is (could be base64/data URL)
            data = artifact.content.data(using: .utf8) ?? Data()
        default:
            // code / markdown: write with language-appropriate extension
            data = artifact.content.data(using: .utf8) ?? Data()
        }
        try data.write(to: url)
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("[Anvil] ArtifactStore save failed: \(error)")
        }
    }
}
