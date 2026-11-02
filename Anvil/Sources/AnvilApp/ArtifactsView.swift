// MARK: - Artifacts sidebar list

import SwiftUI
import AnvilKit

struct ArtifactsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var artifactStore: ArtifactStore
    @State private var newTitle = ""
    @State private var newContent = ""
    @State private var newKind: String = "code"
    @State private var newLanguage = ""
    @State private var showingCreate = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "cube.transparent")
                    .foregroundStyle(themeManager.theme.accent)
                Text("Artifacts")
                    .font(.headline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                Spacer()
                Button("New") { showingCreate = true }
                    .buttonStyle(.plain)
            }
            .padding()
            .background(themeManager.theme.surfaceElevated)

            Divider().background(themeManager.theme.divider)

            if artifactStore.artifacts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 48))
                        .foregroundStyle(themeManager.theme.textMuted)
                    Text("No artifacts yet")
                        .font(.headline)
                        .foregroundStyle(themeManager.theme.textPrimary)
                    Text("Create artifacts from code blocks in chat.")
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(artifactStore.artifacts) { artifact in
                        ArtifactRow(artifact: artifact)
                            .tag(artifact.id)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            artifactStore.deleteArtifact(artifactStore.artifacts[index])
                        }
                    }
                }
                .listStyle(.inset)
                .background(themeManager.theme.background)
            }

            Divider().background(themeManager.theme.divider)

            // Selected artifact detail
            if let artifact = artifactStore.selectedArtifact {
                ArtifactView(artifact: artifact)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .foregroundStyle(themeManager.theme.textMuted)
                    Text("Select an artifact")
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(themeManager.theme.background)
        .sheet(isPresented: $showingCreate) {
            CreateArtifactView(title: $newTitle, content: $newContent,
                               kind: $newKind, language: $newLanguage,
                               onCreate: createArtifact)
        }
    }

    private func createArtifact() {
        guard !newTitle.isEmpty else { return }
        artifactStore.createArtifact(title: newTitle, kind: newKind,
                                     language: newLanguage.isEmpty ? nil : newLanguage,
                                     content: newContent)
        newTitle = ""; newContent = ""; newLanguage = ""
        showingCreate = false
    }
}

private struct ArtifactRow: View {
    let artifact: Artifact
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var artifactStore: ArtifactStore

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: artifact.iconName)
                .foregroundStyle(themeManager.theme.textSecondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.title)
                    .font(.subheadline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                    .lineLimit(1)
                Text("v\(artifact.version) · \(artifact.kind)\(artifact.language.map { " • \($0)" } ?? "")")
                    .font(.caption2)
                    .foregroundStyle(themeManager.theme.textMuted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            artifactStore.selectedArtifact = artifact
        }
    }
}

// MARK: - Create artifact sheet

struct CreateArtifactView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Binding var title: String
    @Binding var content: String
    @Binding var kind: String
    @Binding var language: String
    var onCreate: () -> Void

    let kinds = [("code", "Code"), ("markdown", "Markdown"), ("html", "HTML")]

    var body: some View {
        NavigationStack {
            Form {
                Section("Artifact") {
                    TextField("Title", text: $title)
                    Picker("Kind", selection: $kind) {
                        ForEach(kinds, id: \.0) { k in
                            Text(k.1).tag(k.0)
                        }
                    }
                    .pickerStyle(.segmented)
                    if kind == "code" {
                        TextField("Language (e.g. swift, python)", text: $language)
                    }
                }
                Section("Content") {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("New Artifact")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { onCreate() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
