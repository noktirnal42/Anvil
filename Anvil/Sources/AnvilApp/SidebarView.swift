// MARK: - Session list sidebar

import SwiftUI
import AnvilKit

struct SidebarView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selectedSessionID: UUID?
    @State private var sessions: [Session] = []

    var body: some View {
        List(selection: $selectedSessionID) {
            ForEach(sessions) { session in
                SessionRow(session: session)
                    .tag(session.id)
            }
        }
        .listStyle(.sidebar)
        .background(themeManager.theme.surface)
        .safeAreaInset(edge: .bottom) {
            Button(action: newSession) {
                Label("New session", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding()
            .background(themeManager.theme.surface)
        }
        .onAppear(perform: loadSessions)
    }

    private func loadSessions() {
        // TODO: load from SwiftData model context
        sessions = [
            Session(title: "Refactor authentication", provider: "opencode", model: "opencode-1"),
            Session(title: "Build CLI tool in Swift", provider: "openai", model: "gpt-5"),
            Session(title: "Matrix-themed terminal", provider: "anthropic", model: "claude-opus-4"),
        ]
    }

    private func newSession() {
        let s = Session(title: "New Session")
        sessions.append(s)
        selectedSessionID = s.id
    }
}

private struct SessionRow: View {
    let session: Session
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundStyle(themeManager.theme.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.subheadline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                    .lineLimit(1)
                Text(session.provider + " · " + session.model)
                    .font(.caption2)
                    .foregroundStyle(themeManager.theme.textMuted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
