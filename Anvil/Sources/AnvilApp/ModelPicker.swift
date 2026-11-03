// MARK: - Provider and model picker for the chat composer

import SwiftUI
import AnvilKit

struct ModelPicker: View {
    let session: Session
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var providerRegistry: ProviderRegistry
    @EnvironmentObject private var adapterRegistry: ProviderAdapterRegistry

    @State private var catalogs: [String: [ModelDescriptor]] = [:]
    @State private var customProvider: ProviderDescriptor?
    @State private var customModelId = ""

    var body: some View {
        Menu {
            ForEach(providerRegistry.providers) { provider in
                Menu(provider.name) {
                    let models = catalogs[provider.id] ?? []
                    if models.isEmpty {
                        Text("No models listed by this provider")
                    }
                    ForEach(models) { model in
                        Button(model.name) { choose(provider: provider, modelId: model.id) }
                    }
                    Divider()
                    Button("Custom model…") {
                        customModelId = session.provider == provider.id ? session.model : ""
                        customProvider = provider
                    }
                }
            }
        } label: {
            Label(currentLabel, systemImage: "cpu")
                .font(.callout)
                .foregroundStyle(themeManager.theme.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .task { await loadCatalogs() }
        .sheet(item: $customProvider) { provider in
            VStack(alignment: .leading, spacing: 12) {
                Text("Model for \(provider.name)")
                    .font(.headline)
                TextField("Model id, e.g. gpt-5 or llama3.1", text: $customModelId)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
                HStack {
                    Spacer()
                    Button("Cancel") { customProvider = nil }
                    Button("Use model") {
                        let trimmed = customModelId.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            choose(provider: provider, modelId: trimmed)
                        }
                        customProvider = nil
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(customModelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
        }
    }

    private var currentLabel: String {
        guard !session.model.isEmpty else { return "Choose model" }
        let providerName = providerRegistry.provider(id: session.provider)?.name ?? session.provider
        return "\(providerName) · \(session.model)"
    }

    /// Writes the choice onto the session; SwiftData persists it.
    private func choose(provider: ProviderDescriptor, modelId: String) {
        session.provider = provider.id
        session.model = modelId
    }

    /// Lists models only for providers that speak the OpenAI-compatible API.
    /// Other providers keep the custom-model entry.
    private func loadCatalogs() async {
        for provider in providerRegistry.providers
        where provider.baseURL != nil
            && adapterRegistry.adapter(for: provider.id) is OpenAICompatibleAdapter {
            let models = await OpenAICompatibleAdapter.shared.listModels(for: provider)
            if !models.isEmpty {
                catalogs[provider.id] = models
            }
        }
    }
}
