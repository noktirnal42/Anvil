// MARK: - Git status panel

import SwiftUI
import AnvilKit

struct GitStatusView: View {
    static let savedFolderKey = "anvil.gitWorkingDirectory"

    @Binding var workingDirectory: URL
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var gitClient: GitClient
    @State private var statusFiles: [GitClient.ChangedFile] = []
    @State private var statusError: String?
    @State private var isLoading = false
    @State private var selectedFile: String?
    @State private var diffText = ""
    @State private var diffStaged = false
    @State private var commitMessage = ""
    @State private var isCommitting = false
    @State private var commitError: String?
    @State private var showCommitSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "branch")
                    .foregroundStyle(themeManager.theme.accent)
                Text("Git — \(workingDirectory.lastPathComponent)")
                    .font(.headline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                    .help(workingDirectory.path)
                Spacer()
                Button("Open folder…") { chooseFolder() }
                    .buttonStyle(.plain)
                    .foregroundStyle(themeManager.theme.accent)
                Button("Refresh") { loadStatus() }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
            }
            .padding()
            .background(themeManager.theme.surfaceElevated)

            Divider().background(themeManager.theme.divider)

            // File list
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let statusError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(themeManager.theme.error)
                    Text("Not a Git repository")
                        .font(.headline)
                        .foregroundStyle(themeManager.theme.textPrimary)
                    Text(statusError)
                        .font(.callout)
                        .foregroundStyle(themeManager.theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                    Text("Choose a folder that contains a repository.")
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if statusFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "branch.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundStyle(themeManager.theme.success)
                    Text("Working tree clean")
                        .font(.headline)
                        .foregroundStyle(themeManager.theme.textPrimary)
                    Text("No changes to commit.")
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedFile) {
                    ForEach(statusFiles) { file in
                        GitStatusRow(file: file)
                            .tag(file.path)
                    }
                }
                .listStyle(.inset)
                .background(themeManager.theme.background)
            }

            // Diff preview
            if let selectedFile, !diffText.isEmpty {
                Divider().background(themeManager.theme.divider)
                VStack {
                    HStack {
                        Text(selectedFile)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(themeManager.theme.textPrimary)
                        Spacer()
                        HStack(spacing: 8) {
                            Button(diffStaged ? "Unstaged" : "Staged") {
                                diffStaged.toggle()
                                loadDiff(for: selectedFile)
                            }
                            .buttonStyle(.plain)
                            .controlSize(.small)
                            Button("Stage") {
                                Task { await stageFile(selectedFile) }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(themeManager.theme.background)
                            .background(themeManager.theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .controlSize(.small)
                            Button("Discard") {
                                Task { await discardFile(selectedFile) }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(themeManager.theme.error)
                            .controlSize(.small)
                        }
                    }
                    .padding(8)
                    .background(themeManager.theme.surfaceElevated)

                    ScrollView {
                        Text(diffText)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(themeManager.theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(themeManager.theme.codeBlockBackground)
                }
                .frame(minHeight: 200)
            }

            // Commit bar
            if !statusFiles.isEmpty {
                Divider().background(themeManager.theme.divider)
                VStack(spacing: 8) {
                    TextField("Commit message", text: $commitMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    HStack {
                        if isCommitting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Spacer()
                        if let error = commitError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(themeManager.theme.error)
                        }
                        Button("Commit") {
                            Task { await doCommit() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCommitting)
                    }
                }
                .padding()
                .background(themeManager.theme.surfaceElevated)
            }
        }
        .background(themeManager.theme.background)
        .onAppear(perform: loadStatus)
    }

    // MARK: - Actions

    private func loadStatus() {
        isLoading = true
        Task {
            do {
                self.statusFiles = try await gitClient.status(workingDirectory)
                self.statusError = nil
            } catch {
                // Show the failure instead of an empty list that reads as "clean".
                self.statusFiles = []
                self.statusError = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func loadDiff(for file: String) {
        Task {
            do {
                self.diffText = try await gitClient.diff(workingDirectory, file: file, staged: diffStaged)
            } catch {
                self.diffText = "\(error)"
            }
        }
    }

    /// Lets the user pick the repository. The choice is remembered for next launch.
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = workingDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        workingDirectory = url
        UserDefaults.standard.set(url.path, forKey: Self.savedFolderKey)
        loadStatus()
    }

    private func stageFile(_ path: String) async {
        do {
            try await gitClient.stage(workingDirectory, files: [path])
            await MainActor.run { loadStatus() }
        } catch {
            print("[Git] stage failed: \(error)")
        }
    }

    private func discardFile(_ path: String) async {
        do {
            try await gitClient.discard(workingDirectory, files: [path])
            await MainActor.run { loadStatus() }
        } catch {
            print("[Git] discard failed: \(error)")
        }
    }

    private func doCommit() async {
        isCommitting = true
        commitError = nil
        do {
            try await gitClient.commit(workingDirectory, message: commitMessage)
            commitMessage = ""
            showCommitSheet = false
            loadStatus()
        } catch {
            commitError = error.localizedDescription
        }
        isCommitting = false
    }
}

private struct GitStatusRow: View {
    let file: GitClient.ChangedFile
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconFor(file.staged, file.unstaged))
                .foregroundStyle(colorFor(file.staged, file.unstaged))
                .frame(width: 16)
            Text(file.path)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(themeManager.theme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 16)
            HStack(spacing: 4) {
                if file.staged != .unmodified {
                    Text(shortLabel(file.staged))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(colorFor(file.staged, file.unstaged))
                }
                if file.unstaged != .unmodified {
                    Text(shortLabel(file.unstaged))
                        .font(.caption2)
                        .foregroundStyle(themeManager.theme.textMuted)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func iconFor(_ staged: GitClient.FileStatus, _ unstaged: GitClient.FileStatus) -> String {
        if staged != .unmodified { return "plus.circle.fill" }
        switch unstaged {
        case .modified: return "pencil.circle"
        case .deleted: return "trash.circle"
        case .untracked: return "questionmark.circle"
        case .renamed: return "arrow.left.arrow.right.circle"
        default: return "circle"
        }
    }

    private func colorFor(_ staged: GitClient.FileStatus, _ unstaged: GitClient.FileStatus) -> Color {
        if staged != .unmodified { return themeManager.theme.success }
        switch unstaged {
        case .modified: return themeManager.theme.warning
        case .deleted: return themeManager.theme.error
        case .untracked: return themeManager.theme.textMuted
        case .renamed: return themeManager.theme.accent
        default: return themeManager.theme.textSecondary
        }
    }

    private func shortLabel(_ s: GitClient.FileStatus) -> String {
        switch s {
        case .added: return "added"
        case .modified: return "modified"
        case .deleted: return "deleted"
        case .renamed: return "renamed"
        case .untracked: return "untracked"
        case .conflicted: return "conflict"
        default: return ""
        }
    }
}
