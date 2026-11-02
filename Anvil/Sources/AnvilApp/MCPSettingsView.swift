// MARK: - MCP server settings

import SwiftUI
import AnvilKit

struct MCPSettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var mcpClient: MCPClient
    @State private var newName = ""
    @State private var newCommand = ""
    @State private var newArgs = ""
    @State private var newURL = ""
    @State private var transport: MCPTransportChoice = .stdio
    @State private var showingAdd = false

    enum MCPTransportChoice: String, CaseIterable, Identifiable {
        case stdio = "Local command (stdio)"
        case http = "HTTP URL"
        var id: String { rawValue }
    }

    var body: some View {
        Form {
            Section("MCP Servers") {
                if mcpClient.configs.isEmpty {
                    Text("No MCP servers configured.")
                        .foregroundStyle(themeManager.theme.textMuted)
                        .italic()
                } else {
                    ForEach(mcpClient.configs) { config in
                        MCPServerRow(config: config)
                    }
                }

                Button(action: { showingAdd = true }) {
                    Label("Add MCP server", systemImage: "plus.circle")
                        .foregroundStyle(themeManager.theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .formStyle(.grouped)
        .background(themeManager.theme.background)
        .navigationTitle("MCP Servers")
        .sheet(isPresented: $showingAdd) {
            AddMCPServerView(transport: $transport, name: $newName,
                             command: $newCommand, args: $newArgs, url: $newURL,
                             onAdd: addServer)
        }
    }

    private func addServer() {
        let transport: MCPTransport = switch self.transport {
        case .stdio: .stdio(command: newCommand, args: newArgs.isEmpty ? [] : newArgs.split(separator: " ").map(String.init))
        case .http: .http(url: newURL)
        }
        let config = MCPServerConfig(name: newName.isEmpty ? "Untitled" : newName,
                                     transport: transport, isEnabled: true)
        mcpClient.addServer(config)
        newName = ""; newCommand = ""; newArgs = ""; newURL = ""
        showingAdd = false
    }
}

private struct MCPServerRow: View {
    let config: MCPServerConfig
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var mcpClient: MCPClient
    @State private var isEnabled: Bool

    init(config: MCPServerConfig) {
        self.config = config
        self._isEnabled = State(initialValue: config.isEnabled)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: connectedIcon)
                .foregroundStyle(connectedColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.subheadline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                Text(transportLabel)
                    .font(.caption2)
                    .foregroundStyle(themeManager.theme.textMuted)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, newValue in
                    mcpClient.setEnabled(config, enabled: newValue)
                }
        }
        .padding(.vertical, 2)
        .opacity(config.isEnabled ? 1 : 0.6)
    }

    private var connected: Bool {
        mcpClient.connectedServers.contains(config.id)
    }
    private var connectedIcon: String {
        connected ? "circle.fill" : "circle"
    }
    private var connectedColor: Color {
        connected ? themeManager.theme.success : themeManager.theme.textMuted
    }
    private var transportLabel: String {
        switch config.transport {
        case .stdio(let command, let args):
            return "stdio · \(command)\(args.isEmpty ? "" : " \(args.joined(separator: " "))")"
        case .http(let url):
            return "HTTP · \(url)"
        }
    }
}

// MARK: - Add server sheet

struct AddMCPServerView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Binding var transport: MCPSettingsView.MCPTransportChoice
    @Binding var name: String
    @Binding var command: String
    @Binding var args: String
    @Binding var url: String
    var onAdd: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Transport") {
                    Picker("Type", selection: $transport) {
                        ForEach(MCPSettingsView.MCPTransportChoice.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    TextField("Name", text: $name)
                    switch transport {
                    case .stdio:
                        TextField("Command (e.g. /usr/local/bin/mcp-server)", text: $command)
                        TextField("Arguments (space-separated)", text: $args)
                    case .http:
                        TextField("URL (e.g. http://localhost:8765/mcp)", text: $url)
                    }
                }
            }
            .navigationTitle("Add MCP Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd() }
                        .disabled(name.isEmpty ||
                                  (transport == .stdio && command.isEmpty) ||
                                  (transport == .http && url.isEmpty))
                }
            }
        }
    }
}
