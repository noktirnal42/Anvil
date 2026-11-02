// MARK: - Root layout: sidebar sessions + main content

import SwiftUI
import AnvilKit

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedSessionID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSessionID: $selectedSessionID)
        } detail: {
            if let selectedSessionID {
                ChatView(sessionID: selectedSessionID)
            } else {
                EmptyStateView()
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
