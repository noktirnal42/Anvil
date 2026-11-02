// MARK: - Tool approval dialog

import SwiftUI
import AnvilKit

struct ToolApprovalView: View {
    let call: ToolCall
    let onApprove: () -> Void
    let onDeny: (String) -> Void
    @State private var denyReason = ""
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(themeManager.theme.accent)
                Text("Tool call requested")
                    .font(.headline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                Spacer()
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "server.rack")
                    .foregroundStyle(themeManager.theme.textSecondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(call.serverName ?? "MCP server")
                        .font(.caption)
                        .foregroundStyle(themeManager.theme.textMuted)
                    Text(call.name)
                        .font(.body.monospaced())
                        .foregroundStyle(themeManager.theme.textPrimary)
                }
                Spacer()
            }

            if let args = call.arguments, !args.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "curlybraces")
                        .foregroundStyle(themeManager.theme.textSecondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Arguments")
                            .font(.caption)
                            .foregroundStyle(themeManager.theme.textMuted)
                        Text(argumentsString)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(themeManager.theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(themeManager.theme.codeBlockBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    Spacer()
                }
            }

            HStack(spacing: 10) {
                Button("Deny") {
                    onDeny(denyReason.isEmpty ? "user declined" : denyReason)
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.theme.textSecondary)

                Spacer()

                Button("Allow") {
                    onApprove()
                }
                .buttonStyle(.plain)
                .foregroundStyle(themeManager.theme.background)
                .background(themeManager.theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(20)
        .background(themeManager.theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(themeManager.theme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 8)
        .frame(maxWidth: 460)
    }

    private var argumentsString: String {
        guard let args = call.arguments else { return "{}" }
        if let data = try? JSONSerialization.data(withJSONObject: args, options: [.prettyPrinted]),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "\(args)"
    }
}


