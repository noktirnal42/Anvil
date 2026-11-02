// MARK: - Settings stub (provider + theme + keys)

import SwiftUI
import AnvilKit

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var registry = ProviderRegistry.shared

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Appearance", selection: .init(
                    get: { themeManager.theme.id },
                    set: { newID in
                        if let t = AnvilTheme.all.first(where: { $0.id == newID }) {
                            themeManager.select(t)
                        }
                    }
                )) {
                    ForEach(AnvilTheme.all) { theme in
                        Text(theme.displayName).tag(theme.id)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Providers") {
                ForEach(registry.providers) { provider in
                    HStack {
                        Text(provider.name)
                        Spacer()
                        Text(provider.isLocal ? "local" : "remote")
                            .font(.caption2)
                            .foregroundStyle(themeManager.theme.textMuted)
                    }
                }
            }

            Section("API Keys (Keychain)") {
                ForEach(["openai", "anthropic", "openrouter", "nvidia-nim", "google-gemini"], id: \.self) { id in
                    HStack {
                        Text(id.capitalized)
                        Spacer()
                        Button("Set key") {
                            // TODO: key entry sheet
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .background(themeManager.theme.background)
    }
}
