// MARK: - Root layout: sidebar sessions + main content

import SwiftUI
import AnvilKit

struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var gitClient: GitClient
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedSessionID: UUID?
    @State private var gitWorkingDirectory = ContentView.savedGitDirectory()

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSessionID: $selectedSessionID)
        } detail: {
            Group {
                if let session = sessionStore.selectedSession {
                    TabView {
                        ChatView(session: session)
                            .tabItem { Label("Chat", systemImage: "message") }
                        TerminalView()
                            .tabItem { Label("Terminal", systemImage: "terminal") }
                        Group {
                            GitStatusView(workingDirectory: $gitWorkingDirectory)
                                .tabItem { Label("Git", systemImage: "branch") }
                            ArtifactsView()
                                .tabItem { Label("Artifacts", systemImage: "cube.transparent") }
                            FileTreeView()
                                .tabItem { Label("Files", systemImage: "folder") }
                            ComputerUseView()
                                .tabItem { Label("Computer", systemImage: "desktopcomputer") }
                        }
                    }
                } else {
                    EmptyStateView()
                }
            }
        }
        .onChange(of: selectedSessionID) { _, newID in
            sessionStore.selectedSession = sessionStore.sessions.first { $0.id == newID }
        }
        // Keep system controls readable on the theme's background.
        .preferredColorScheme(themeManager.theme.isDark ? .dark : .light)
    }

    /// The Git tab's repository: the last folder the user chose, else the home folder.
    /// An app launched from Finder starts in "/", which is not a repository.
    static func savedGitDirectory() -> URL {
        if let path = UserDefaults.standard.string(forKey: GitStatusView.savedFolderKey),
           FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            AnvilMark(accent: themeManager.theme.accent)
                .frame(width: 96, height: 96)
            Text("Anvil")
                .font(.title2.bold())
                .foregroundStyle(themeManager.theme.textPrimary)
            Text("Start a new session to begin.")
                .foregroundStyle(themeManager.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.theme.background)
    }
}
