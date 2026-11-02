// MARK: - Root layout: sidebar sessions + main content

import SwiftUI
import AnvilKit

struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var gitClient: GitClient
    @State private var selectedSessionID: UUID?
    @State private var gitWorkingDirectory: URL?

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
                        if let gitURL = gitWorkingDirectory {
                            GitStatusView(workingDirectory: gitURL)
                                .tabItem { Label("Git", systemImage: "branch") }
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
        .onAppear {
            if gitWorkingDirectory == nil {
                gitWorkingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            }
        }
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "atom")
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.theme.accent)
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
