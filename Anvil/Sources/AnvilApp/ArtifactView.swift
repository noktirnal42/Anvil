// MARK: - Artifact view (rendered artifact + version history + export)

import SwiftUI
import UniformTypeIdentifiers
import AnvilKit

struct ArtifactView: View {
    let artifact: Artifact
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var artifactStore: ArtifactStore
    @State private var selectedVersion: Int?
    @State private var exportMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: artifactIcon)
                    .foregroundStyle(themeManager.theme.accent)
                Text(artifact.title)
                    .font(.headline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                Spacer()
                Text("v\(artifact.version)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(themeManager.theme.textSecondary)
                Menu {
                    Button("Copy content") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(artifact.content, forType: .string)
                    }
                    Button("Export…") {
                        exportArtifact()
                    }
                    Button("Delete artifact", role: .destructive) {
                        artifactStore.deleteArtifact(artifact)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
                .menuIndicator(.hidden)
            }
            .padding()
            .background(themeManager.theme.surfaceElevated)

            Divider().background(themeManager.theme.divider)

            // Rendered content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    contentView
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(themeManager.theme.background)

            // Version history
            if !artifact.versions.isEmpty {
                Divider().background(themeManager.theme.divider)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Versions")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.theme.textMuted)
                        .padding(.horizontal)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(artifact.versions.sorted { $0.version < $1.version }) { v in
                                Button("v\(v.version)") {
                                    restoreVersion(v)
                                }
                                .buttonStyle(.plain)
                                .controlSize(.small)
                                .foregroundStyle(selectedVersion == v.version
                                                 ? themeManager.theme.accent
                                                 : themeManager.theme.textSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedVersion == v.version
                                                ? themeManager.theme.accent
                                                : Color.clear, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(themeManager.theme.surfaceElevated)
            }
        }
        .background(themeManager.theme.background)
    }

    @ViewBuilder
    private var contentView: some View {
        switch artifact.kind {
        case "html":
            // placeholder: render raw html as text (WebKit preview in v2)
            Text(artifact.content)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(themeManager.theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case "markdown":
            Text(artifact.content)
                .font(.body)
                .foregroundStyle(themeManager.theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        default: // code
            Text(artifact.content)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(themeManager.theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var artifactIcon: String {
        switch artifact.kind {
        case "html": return "curlybraces.square"
        case "markdown": return "doc.richtext"
        case "image": return "photo"
        default: return "chevron.left.forwardslash.chevron.right"
        }
    }

    private func restoreVersion(_ version: ArtifactVersion) {
        artifactStore.updateArtifact(artifact, content: version.content,
                                     title: nil, note: "restored from v\(version.version)")
        selectedVersion = version.version
    }

    // MARK: - Export

    private func exportArtifact() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [artifactContentType]
        panel.nameFieldStringValue = defaultFileName
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try self.artifactStore.exportArtifact(self.artifact, to: url)
                self.exportMessage = "Exported to \(url.lastPathComponent)"
            } catch {
                self.exportMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private var defaultFileName: String {
        let safeTitle = artifact.title.replacingOccurrences(of: "/", with: "-")
        switch artifact.kind {
        case "html": return "\(safeTitle).html"
        case "markdown": return "\(safeTitle).md"
        case "image": return "\(safeTitle).png"
        default:
            let ext = (artifact.language?.isEmpty == false) ? "\(artifact.language!).txt" : "txt"
            return "\(safeTitle).\(ext)"
        }
    }

    private var artifactContentType: UTType {
        switch artifact.kind {
        case "html": return .html
        case "markdown": return .plainText
        case "image": return .png
        default: return .sourceCode
        }
    }
}
