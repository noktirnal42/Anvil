// MARK: - App entry point

import SwiftData
import SwiftUI
import AnvilKit

@main
struct AnvilApp: App {
    @StateObject private var providerRegistry = ProviderRegistry.shared
    @StateObject private var sessionStore = SessionStore.shared
    @StateObject private var agentRunner = AgentRunner.shared
    @StateObject private var mcpClient = MCPClient.shared
    @StateObject private var gitClient = GitClient.shared
    @StateObject private var artifactStore = ArtifactStore.shared
    @StateObject private var fileIndex = FileIndexService.shared
    @State private var showQuickOpen = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(providerRegistry)
                .environmentObject(sessionStore)
                .environmentObject(agentRunner)
                .environmentObject(mcpClient)
                .environmentObject(gitClient)
                .environmentObject(artifactStore)
                .environmentObject(fileIndex)
                .anvilTheme()
                .sheet(isPresented: $showQuickOpen) {
                    QuickOpenView()
                }
                .frame(minWidth: 1100, minHeight: 750)
        }
        .modelContainer(SwiftDataStack.shared.container)
        .windowStyle(.titleBar)
        .commands {
            CommandMenu("Providers") {
                ForEach(providerRegistry.providers) { provider in
                    Button(provider.name) {
                        // TODO: select provider for active session
                    }
                }
            }
            CommandMenu("File") {
                Button("Open file… (⌘P)") {
                    showQuickOpen = true
                }
                .keyboardShortcut("p", modifiers: .command)
            }
        }
    }
}
