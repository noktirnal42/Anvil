// MARK: - File index service (Spotlight NSMetadataQuery)

import Foundation
import SwiftData

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

    private var query: NSMetadataQuery?
    private var queryTimer: Timer?
    private var queryObservers: [NSObjectProtocol] = []

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

    // MARK: - Indexing (Spotlight)

    public func startIndexing() {
        guard !isIndexing else { return }
        isIndexing = true

        // Run a spotlight query over indexed folders' items
        let query = NSMetadataQuery()
        self.query = query

        var scopes: [String] = []
        for folder in indexedFolders {
            scopes.append(folder.path)
        }
        guard !scopes.isEmpty else {
            isIndexing = false
            return
        }
        query.searchScopes = scopes
        query.predicate = NSPredicate(format: "kMDItemKind != 'Folder'")

        var obs1: NSObjectProtocol?
        var obs2: NSObjectProtocol?
        obs1 = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.processResults(self?.query?.results ?? [])
        }
        obs2 = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.processResults(self?.query?.results ?? [])
            self?.stopQuery()
        }
        // keep observers alive for the query's lifetime
        queryObservers = [obs1, obs2].compactMap { $0 }

        query.start()
        queryObservers = []
        // Spotlight queries run continuously; stop gathering after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.stopQuery()
        }
    }

    private func stopQuery() {
        query?.stop()
        query = nil
        queryObservers.removeAll()
        isIndexing = false
    }

    private func processResults(_ results: [Any]) {
        var records: [FileRecord] = []
        for item in results {
            guard let mdItem = item as? NSMetadataItem,
                  let path = mdItem.value(forAttribute: kMDItemPath as String) as? String,
                  let name = mdItem.value(forAttribute: kMDItemDisplayName as String) as? String
            else { continue }
            let uti = mdItem.value(forAttribute: kMDItemContentType as String) as? String
            records.append(FileRecord(path: path, name: name, uti: uti))
        }
        // Persist
        files.removeAll()
        for rec in records {
            context.insert(rec)
        }
        save()
        self.files = records.sorted { $0.name < $1.name }
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
