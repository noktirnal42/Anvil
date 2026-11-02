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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(providerRegistry)
                .environmentObject(sessionStore)
                .environmentObject(agentRunner)
                .environmentObject(mcpClient)
                .environmentObject(gitClient)
                .anvilTheme()
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
        }
    }
}
