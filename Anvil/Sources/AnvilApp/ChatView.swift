// MARK: - Chat view (streaming messages + tool approvals)

import SwiftUI
import AnvilKit

struct ChatView: View {
    let session: Session
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var providerRegistry: ProviderRegistry
    @EnvironmentObject private var adapterRegistry: ProviderAdapterRegistry
    @EnvironmentObject private var nativeEngine: NativeSessionEngine
    @EnvironmentObject private var mcpClient: MCPClient
    @State private var inputText = ""
    @State private var isStreaming = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(session.messages.sorted { $0.createdAt < $1.createdAt }) { message in
                        MessageBubble(message: message)
                    }
                    // Round in-progress indicator
                    if isStreaming && !nativeEngine.roundText.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Spacer(minLength: 60)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(nativeEngine.roundText.isEmpty ? "…" : nativeEngine.roundText)
                                    .foregroundStyle(themeManager.theme.textPrimary)
                                    .padding(12)
                                    .background(themeManager.theme.chatBubbleAssistant)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                HStack(spacing: 4) {
                                    ForEach(0..<3) { i in
                                        Circle()
                                            .fill(themeManager.theme.accent)
                                            .frame(width: 5, height: 5)
                                            .scaleEffect(i == 0 ? 1.2 : 0.8)
                                            .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2 * Double(i)), value: isStreaming)
                                    }
                                }
                                .padding(.leading, 4)
                            }
                            Spacer(minLength: 60)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.theme.background)
            }
            .background(themeManager.theme.background)

            Divider().background(themeManager.theme.divider)

            HStack {
                ModelPicker(session: session)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .background(themeManager.theme.surfaceElevated)

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
                    .onSubmit { send() }
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
        // Tool approval modal overlay
        .overlay(
            Group {
                if let call = nativeEngine.pendingToolCall {
                    ZStack {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture { /* dismiss on backdrop tap is disabled; must choose */ }
                        ToolApprovalView(call: call,
                                         onApprove: nativeEngine.approveCurrentToolCall,
                                         onDeny: nativeEngine.denyCurrentToolCall(reason:))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            },
            alignment: .center
        )
        .animation(.spring(), value: nativeEngine.pendingToolCall != nil)
        .onAppear {
            sessionStore.selectedSession = session
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""

        let descriptor = providerRegistry.provider(id: session.provider) ?? providerRegistry.default
        isStreaming = true

        Task { @MainActor in
            await nativeEngine.run(session: session, descriptor: descriptor,
                                   model: session.model,
                                   userMessage: text, store: sessionStore,
                                   onComplete: {
                                       isStreaming = false
                                   })
        }
    }

    private func stop() {
        nativeEngine.stop()
        isStreaming = false
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
                // Provider failures stand out so a silent stall is never mistaken for a reply
                if message.role == "error" {
                    Label(message.content, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(themeManager.theme.error)
                        .padding(12)
                        .background(themeManager.theme.error.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                // Tool results render distinctly
                } else if message.role == "tool" {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .foregroundStyle(themeManager.theme.textMuted)
                            Text(message.toolName ?? "tool")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(themeManager.theme.textMuted)
                            if message.toolCallId != nil {
                                Text(message.toolCallId!)
                                    .font(.caption2)
                                    .foregroundStyle(themeManager.theme.textMuted)
                            }
                            Spacer()
                        }
                        Text(message.content.isEmpty ? "…" : message.content)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(themeManager.theme.textSecondary)
                            .padding(10)
                            .background(themeManager.theme.codeBlockBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .padding(.horizontal, 8)
                } else {
                    Text(message.content.isEmpty ? "…" : message.content)
                        .foregroundStyle(message.role == "user" ? themeManager.theme.background : themeManager.theme.textPrimary)
                        .padding(12)
                        .background(message.role == "user" ? themeManager.theme.chatBubbleUser : themeManager.theme.chatBubbleAssistant)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(themeManager.theme.border, lineWidth: 0.5)
                        )
                }
            }
            if message.role != "user" {
                Spacer(minLength: 60)
            }
        }
    }
}
