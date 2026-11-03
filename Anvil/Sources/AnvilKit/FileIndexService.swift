// MARK: - File index service (direct filesystem walk)

// Indexes the folders the user adds by walking them on a background thread.
// This does not depend on Spotlight, which is often partly or wholly disabled
// on a Mac and never covers some volumes.

import Foundation
import SwiftData
import UniformTypeIdentifiers

/// A file found by the scan. Plain values, so they can cross threads safely.
struct ScannedFile: Sendable, Equatable {
    let path: String
    let name: String
    let uti: String?
}

/// Folders that hold dependencies or build output. They are never indexed.
private let skippedFolderNames: Set<String> = [
    "node_modules", ".build", ".git", "DerivedData", "Pods"
]

/// Upper bound so one huge folder cannot stall the app or fill the store.
let fileIndexLimit = 20_000

@MainActor
public final class FileIndexService: ObservableObject {
    public static let shared = FileIndexService()

    public let context: ModelContext

    private init() {
        self.context = SwiftDataStack.shared.mainContext
        loadIndexedFolders()
        loadFiles()
    }

    @Published public var indexedFolders: [IndexedFolder] = []
    @Published public var files: [FileRecord] = []
    @Published public var isIndexing = false

    // MARK: - Folders

    public func loadIndexedFolders() {
        let descriptor = FetchDescriptor<IndexedFolder>(
            sortBy: [SortDescriptor(\IndexedFolder.addedAt, order: .reverse)]
        )
        if let fetched = try? context.fetch(descriptor) {
            indexedFolders = fetched
        }
    }

    public func addFolder(_ url: URL) {
        guard !indexedFolders.contains(where: { $0.path == url.path }) else { return }
        let folder = IndexedFolder(path: url.path, name: url.lastPathComponent)
        context.insert(folder)
        save()
        loadIndexedFolders()
        startIndexing()
    }

    public func removeFolder(_ folder: IndexedFolder) {
        context.delete(folder)
        save()
        loadIndexedFolders()
        // also remove its files
        files.removeAll { $0.path.hasPrefix(folder.path) }
        save()
        loadFiles()
    }

    // MARK: - Indexing

    /// Re-scans every indexed folder in the background and replaces the file list.
    public func startIndexing() {
        guard !isIndexing, !indexedFolders.isEmpty else { return }
        isIndexing = true
        let roots = indexedFolders.map { URL(fileURLWithPath: $0.path) }

        Task {
            let found = await Task.detached(priority: .utility) {
                Self.scan(roots: roots, limit: fileIndexLimit)
            }.value
            replaceIndex(with: found)
            isIndexing = false
        }
    }

    /// Walks each root and returns its regular files. Hidden files, package
    /// contents and the folders in `skippedFolderNames` are left out.
    nonisolated static func scan(roots: [URL], limit: Int) -> [ScannedFile] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentTypeKey]
        var found: [ScannedFile] = []
        for root in roots {
            guard let walker = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in walker {
                if skippedFolderNames.contains(url.lastPathComponent) {
                    walker.skipDescendants()
                    continue
                }
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      values.isRegularFile == true else { continue }
                found.append(ScannedFile(path: url.path,
                                         name: url.lastPathComponent,
                                         uti: values.contentType?.identifier))
                if found.count >= limit { return found }
            }
        }
        return found
    }

    private func replaceIndex(with found: [ScannedFile]) {
        try? context.delete(model: FileRecord.self)
        for file in found {
            context.insert(FileRecord(path: file.path, name: file.name, uti: file.uti))
        }
        save()
        loadFiles()
    }

    // MARK: - Files

    public func loadFiles() {
        let descriptor = FetchDescriptor<FileRecord>(
            sortBy: [SortDescriptor(\FileRecord.name, order: .forward)]
        )
        if let fetched = try? context.fetch(descriptor) {
            files = fetched
        }
    }

    public func searchFiles(query: String) -> [FileRecord] {
        guard !query.isEmpty else { return files }
        let lower = query.lowercased()
        return files.filter {
            $0.name.lowercased().contains(lower) ||
            $0.path.lowercased().contains(lower)
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("[FileIndex] save failed: \(error)")
        }
    }
}
