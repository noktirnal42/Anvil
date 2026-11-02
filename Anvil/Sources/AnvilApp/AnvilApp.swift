// MARK: - App entry point

import SwiftUI
import AnvilKit

@main
struct AnvilApp: App {
    @StateObject private var providerRegistry = ProviderRegistry.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(providerRegistry)
                .anvilTheme()
                .frame(minWidth: 1100, minHeight: 750)
        }
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
