// MARK: - Chat view (streaming messages + tool approvals)

import SwiftUI
import AnvilKit

struct ChatView: View {
    let sessionID: UUID
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var inputText = ""
    @State private var messages: [Message] = [
        Message(role: "assistant", content: "Hi — I'm Anvil. Pick a model and start building.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
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
            .padding(10)
            .background(themeManager.theme.surfaceElevated)
        }
        .background(themeManager.theme.background)
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(Message(role: "user", content: text))
        messages.append(Message(role: "assistant", content: "", isStreaming: true))
        // TODO: stream from provider/OpenCodeBridge
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
