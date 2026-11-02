// MARK: - Terminal view

import SwiftUI
import Combine
import AnvilKit

struct TerminalView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @ObservedObject private var pty = PTYTerminal.shared
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pty.output)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(ptyThemeText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        Spacer(minLength: 1)
                            .id("end")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(ptyThemeBackground)
                }
                .background(ptyThemeBackground)
                .onAppear { scrollProxy = proxy }
                .onReceive(pty.$output) { _ in
                    scrollProxy?.scrollTo("end", anchor: .bottom)
                }
            }
            .background(ptyThemeBackground)

            Divider().background(ptyThemeBorder)

            HStack(spacing: 8) {
                if pty.isRunning {
                    Button(action: { pty.signal(SIGINT) }) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundStyle(themeManager.theme.error)
                    }
                    .buttonStyle(.plain)
                    .help("Ctrl-C")
                }
                TextField("Terminal input…", text: $inputText)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(themeManager.theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(themeManager.theme.border, lineWidth: 1)
                    )
                    .foregroundStyle(themeManager.theme.textPrimary)
                    .disabled(!pty.isRunning)
                    .submitLabel(.send)
                    .onSubmit {
                        pty.write(inputText + "\n")
                        inputText = ""
                    }
                Button(action: sendInput) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(themeManager.theme.background)
                        .frame(width: 32, height: 32)
                        .background(themeManager.theme.accent)
                        .clipShape(Circle())
                }
                .disabled(!pty.isRunning || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.plain)
                Button(action: { pty.clear(); inputText = "" }) {
                    Image(systemName: "trash")
                        .foregroundStyle(themeManager.theme.textMuted)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
            .padding(8)
            .background(themeManager.theme.surfaceElevated)
        }
        .background(themeManager.theme.background)
        .onAppear {
            if !pty.isRunning {
                pty.start()
            }
        }
    }

    private func sendInput() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        pty.write(text + "\n")
        inputText = ""
    }

    // MARK: - Theme-derived terminal colors

    private var ptyThemeBackground: Color {
        themeManager.theme.terminalBackground
    }
    private var ptyThemeText: Color {
        themeManager.theme.terminalText
    }
    private var ptyThemeBorder: Color {
        themeManager.theme.border
    }
}
