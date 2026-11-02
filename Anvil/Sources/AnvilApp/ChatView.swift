// MARK: - Chat view (streaming messages + tool approvals)

import SwiftUI
import AnvilKit

struct ChatView: View {
    let session: Session
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var providerRegistry: ProviderRegistry
    @State private var inputText = ""
    @State private var streamingTask: Task<Void, Never>?
    @State private var isStreaming = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(session.messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.theme.background)
            }
            .background(themeManager.theme.background)

            Divider().background(themeManager.theme.divider)

            HStack(spacing: 10) {
                TextField("Message Anvil…", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(themeManager.theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(themeManager.theme.border, lineWidth: 1)
                    )
                    .foregroundStyle(themeManager.theme.textPrimary)
                    .submitLabel(.send)
                    .onSubmit {
                        send()
                    }
                    .disabled(isStreaming)
                if isStreaming {
                    Button(action: stop) {
                        Image(systemName: "stop.fill")
                            .foregroundStyle(themeManager.theme.background)
                            .frame(width: 36, height: 36)
                            .background(themeManager.theme.error)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(themeManager.theme.background)
                            .frame(width: 36, height: 36)
                            .background(themeManager.theme.accent)
                            .clipShape(Circle())
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(themeManager.theme.surfaceElevated)
        }
        .background(themeManager.theme.background)
        .onAppear {
            sessionStore.selectedSession = session
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        streamingTask = Task { @MainActor in
            let provider = providerRegistry.provider(id: session.provider) ?? providerRegistry.default

            // Persist user message
            _ = sessionStore.appendMessage(to: session, role: "user", content: text, isComplete: true)

            // Start assistant streaming message
            _ = sessionStore.appendMessage(to: session, role: "assistant",
                                           content: "", isStreaming: true, isComplete: false)
            isStreaming = true

            let prior = session.messages
            await ChatClient.shared.stream(session: session, provider: provider,
                                           messages: prior,
                                           onDelta: { [weak sessionStore] delta in
                                            guard let sessionStore,
                                                  let s = sessionStore.sessions.first(where: { $0.id == session.id }),
                                                  let last = s.messages.last else { return }
                                            let updated = last.content + delta
                                            sessionStore.updateLastMessage(in: s,
                                                                           content: updated,
                                                                           isStreaming: true,
                                                                           isComplete: false)
                                           },
                                           onComplete: { [weak sessionStore] in
                                            guard let sessionStore,
                                                  let s = sessionStore.sessions.first(where: { $0.id == session.id }),
                                                  let last = s.messages.last else { return }
                                            sessionStore.updateLastMessage(in: s,
                                                                           content: last.content,
                                                                           isStreaming: false,
                                                                           isComplete: true)
                                            isStreaming = false
                                            streamingTask = nil
                                           })
        }
    }

    private func stop() {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        if let last = session.messages.last, last.isStreaming {
            sessionStore.updateLastMessage(in: session, content: last.content,
                                           isStreaming: false, isComplete: true)
        }
    }
}

private struct MessageBubble: View {
    let message: Message
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == "user" {
                Spacer(minLength: 60)
            }
            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content.isEmpty ? "…" : message.content)
                    .foregroundStyle(message.role == "user" ? themeManager.theme.background : themeManager.theme.textPrimary)
                    .padding(12)
                    .background(message.role == "user" ? themeManager.theme.chatBubbleUser : themeManager.theme.chatBubbleAssistant)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.theme.border, lineWidth: 0.5)
                    )
                if message.role == "assistant" && message.isStreaming {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(themeManager.theme.accent)
                                .frame(width: 5, height: 5)
                                .scaleEffect(i == 0 ? 1.2 : 0.8)
                                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2 * Double(i)), value: message.isStreaming)
                        }
                    }
                    .padding(.leading, 4)
                }
            }
            if message.role != "user" {
                Spacer(minLength: 60)
            }
        }
    }
}
