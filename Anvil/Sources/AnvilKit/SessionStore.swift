// MARK: - Session store (actor-bound CRUD; System5 concurrency discipline)

import Foundation
import SwiftData

@MainActor
public final class SessionStore: ObservableObject {
    public static let shared = SessionStore()
    public let context: ModelContext

    @Published public var sessions: [Session] = []
    @Published public var selectedSession: Session?

    private init() {
        self.context = SwiftDataStack.shared.mainContext
        loadSessions()
    }

    // MARK: - Sessions

    public func loadSessions() {
        let descriptor = FetchDescriptor<Session>(
            sortBy: [SortDescriptor(\Session.updatedAt, order: .reverse)]
        )
        if let fetched = try? context.fetch(descriptor) {
            sessions = fetched
        }
    }

    public func createSession(title: String = "New Session",
                              provider: String = "opencode",
                              model: String = "") -> Session {
        let session = Session(title: title, provider: provider, model: model)
        context.insert(session)
        save()
        sessions.insert(session, at: 0)
        selectedSession = session
        return session
    }

    public func deleteSession(_ session: Session) {
        if selectedSession?.id == session.id {
            selectedSession = sessions.first { $0.id != session.id }
        }
        context.delete(session)
        save()
        loadSessions()
    }

    public func renameSession(_ session: Session, to title: String) {
        session.title = title
        session.updatedAt = .now
        save()
    }

    // MARK: - Messages

    public func appendMessage(to session: Session, role: String, content: String = "",
                              toolCallId: String? = nil, toolName: String? = nil,
                              toolArguments: String? = nil, isStreaming: Bool = false,
                              isComplete: Bool = false) -> Message {
        let message = Message(role: role, content: content,
                              toolCallId: toolCallId, toolName: toolName,
                              toolArguments: toolArguments,
                              isStreaming: isStreaming, isComplete: isComplete)
        session.messages.append(message)
        session.updatedAt = .now
        save()
        return message
    }

    public func updateLastMessage(in session: Session, content: String,
                                  isStreaming: Bool, isComplete: Bool) {
        guard let last = session.messages.last else { return }
        last.content = content
        last.isStreaming = isStreaming
        last.isComplete = isComplete
        session.updatedAt = .now
        save()
    }

    public func save() {
        do {
            try context.save()
        } catch {
            print("[Anvil] SwiftData save failed: \(error)")
        }
    }
}
