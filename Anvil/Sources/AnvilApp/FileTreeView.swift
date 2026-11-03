// MARK: - File tree view (sidebar)

import SwiftUI
import AnvilKit

struct FileTreeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var index: FileIndexService
    @State private var selectedFile: FileRecord?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder")
                    .foregroundStyle(themeManager.theme.accent)
                Text("Files")
                    .font(.headline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                Spacer()
                Button("Add folder") { addFolderPressed = true }
                    .buttonStyle(.plain)
                    .controlSize(.small)
            }
            .padding()
            .background(themeManager.theme.surfaceElevated)

            Divider().background(themeManager.theme.divider)

            if index.indexedFolders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundStyle(themeManager.theme.textMuted)
                    Text("No indexed folders")
                        .font(.headline)
                        .foregroundStyle(themeManager.theme.textPrimary)
                    Text("Add a folder to index its files for quick open.")
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedFile) {
                    ForEach(index.indexedFolders) { folder in
                        Section(folder.name) {
                            let folderFiles = index.files.filter { $0.path.hasPrefix(folder.path) }
                            if folderFiles.isEmpty {
                                Text("(no files indexed yet)")
                                    .font(.caption)
                                    .foregroundStyle(themeManager.theme.textMuted)
                            } else {
                                ForEach(folderFiles) { file in
                                    FileRow(file: file)
                                        .tag(file.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .background(themeManager.theme.background)
            }

            // Preview / open bar
            if let file = selectedFile {
                VStack {
                    HStack {
                        Text(file.name)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(themeManager.theme.textPrimary)
                        Spacer()
                        Button("Open") { openFile(file) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        Button("Show in Finder") { showInFinder(file) }
                            .buttonStyle(.plain)
                            .controlSize(.small)
                    }
                    .padding(8)
                    .background(themeManager.theme.surfaceElevated)
                }
                .frame(minHeight: 60)
            }
        }
        .background(themeManager.theme.background)
        .sheet(isPresented: $addFolderPressed) {
            AddFolderView { url in
                index.addFolder(url)
            }
        }
    }

    @State private var addFolderPressed = false

    private func openFile(_ file: FileRecord) {
        NSWorkspace.shared.open(URL(fileURLWithPath: file.path))
    }

    private func showInFinder(_ file: FileRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: file.path)])
    }
}

private struct FileRow: View {
    let file: FileRecord
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconFor(uti: file.uti))
                .foregroundStyle(themeManager.theme.textSecondary)
                .frame(width: 16)
            Text(file.name)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(themeManager.theme.textPrimary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 1)
    }

    private func iconFor(uti: String?) -> String {
        guard let uti else { return "doc" }
        switch uti {
        case "public.swift-source": return "swift"
        case "public.python-script", "public.python-source": return "python"
        case "public.java-source": return "java"
        case "public.c-source": return "c"
        case "public.cpp-source": return "cpp"
        case "public.javascript": return "javascript"
        case "public.json": return "curlybraces"
        case "public.plain-text": return "doc.text"
        case "public.markdown": return "doc.richtext"
        default: return "doc"
        }
    }
}

// MARK: - Add folder sheet

struct AddFolderView: View {
    @Environment(\.dismiss) private var dismiss
    var onAdd: (URL) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Index a folder")
                .font(.headline)
            Text("Choose a folder to index its files for quick open (⌘P).")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Choose folder…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    onAdd(url)
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(width: 420, height: 240)
        .padding()
    }
}

// MARK: - Quick-open overlay (⌘P)

struct QuickOpenView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var index: FileIndexService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [FileRecord] = []
    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            TextField("Open file…", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .onChange(of: query) { _, newValue in
                    results = index.searchFiles(query: newValue)
                    selectedIndex = 0
                }

            Divider()

            List(results, id: \.id, selection: $selectedIndex) { file in
                HStack {
                    Image(systemName: iconFor(uti: file.uti))
                        .foregroundStyle(themeManager.theme.textSecondary)
                        .frame(width: 16)
                    Text(file.name)
                        .foregroundStyle(themeManager.theme.textPrimary)
                    Spacer()
                    Text(file.path)
                        .font(.caption2)
                        .foregroundStyle(themeManager.theme.textMuted)
                        .lineLimit(1)
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Text("\(results.count) results")
                    .font(.caption2)
                    .foregroundStyle(themeManager.theme.textMuted)
                Spacer()
                Text("⏎ Open   ⎋ Cancel")
                    .font(.caption2)
                    .foregroundStyle(themeManager.theme.textMuted)
            }
            .padding(8)
            .background(themeManager.theme.surfaceElevated)
        }
        .frame(width: 640, height: 480)
        .background(themeManager.theme.background)
        .onAppear {
            results = index.files
        }
    }

    private func iconFor(uti: String?) -> String {
        guard let uti else { return "doc" }
        switch uti {
        case "public.swift-source": return "swift"
        case "public.python-script": return "python"
        case "public.javascript": return "javascript"
        case "public.json": return "curlybraces"
        default: return "doc"
        }
    }
}
