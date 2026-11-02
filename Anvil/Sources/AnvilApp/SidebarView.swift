// MARK: - Session list sidebar

import SwiftUI
import AnvilKit

struct SidebarView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var sessionStore: SessionStore
    @Binding var selectedSessionID: UUID?

    var body: some View {
        List(selection: $selectedSessionID) {
            ForEach(sessionStore.sessions) { session in
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
    }

    private func newSession() {
        _ = sessionStore.createSession()
    }
}

private struct SessionRow: View {
    let session: Session
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundStyle(themeManager.theme.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.subheadline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                    .lineLimit(1)
                Text(session.provider + " · " + (session.model.isEmpty ? "—" : session.model))
                    .font(.caption2)
                    .foregroundStyle(themeManager.theme.textMuted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Delete session", role: .destructive) {
                sessionStore.deleteSession(session)
            }
        }
    }
}
