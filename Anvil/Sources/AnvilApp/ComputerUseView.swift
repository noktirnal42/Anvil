// MARK: - Computer Use view (WebKit browser + AX control)

import SwiftUI
import WebKit
import AnvilKit

struct ComputerUseView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var ax: AXController
    @State private var urlString = "https://example.com"
    @State private var webView: WKWebView?
    @State private var showingInspector = false
    @State private var axTree: AXElement?
    @State private var inspecting = false

    var body: some View {
        VStack(spacing: 0) {
            // Address bar + controls
            HStack(spacing: 8) {
                TextField("URL", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.go)
                    .onSubmit { loadURL() }

                Button("Go") { loadURL() }
                    .buttonStyle(.bordered)
                Button("Refresh") {
                    webView?.reload()
                }
                .buttonStyle(.plain)
                .controlSize(.small)

                Divider().frame(height: 20)

                Button("Check AX access") {
                    ax.checkAXAccess()
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .foregroundStyle(ax.isAXEnabled ? Color.green : Color.secondary)

                Button("Inspect screen") {
                    inspectScreen()
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .disabled(inspecting)
                .overlay {
                    if inspecting { ProgressView().controlSize(.small) }
                }

                Spacer()

                Text(ax.isAXEnabled ? "AX: enabled" : "AX: disabled")
                    .font(.caption2)
                    .foregroundStyle(ax.isAXEnabled ? Color.green : Color.red)
            }
            .padding(8)
            .background(themeManager.theme.surfaceElevated)

            Divider().background(themeManager.theme.divider)

            // Browser
            ZStack {
                WebView(urlString: $urlString, webView: $webView)
                    .background(themeManager.theme.background)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(themeManager.theme.background)
        .sheet(isPresented: $showingInspector) {
            AXInspectorView(tree: axTree)
        }
        .onAppear {
            ax.checkAXAccess()
        }
    }

    private func loadURL() {
        guard let url = URL(string: urlString),
              url.scheme != nil else {
            urlString = "https://\(urlString)"
            loadURL()
            return
        }
        webView?.load(URLRequest(url: url))
    }

    private func inspectScreen() {
        inspecting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.axTree = self.ax.inspectFocusedApp(maxDepth: 3)
            self.inspecting = false
            self.showingInspector = true
        }
    }
}

// MARK: - WebView (WKWebView bridge)

struct WebView: NSViewRepresentable {
    @Binding var urlString: String
    @Binding var webView: WKWebView?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        if let url = URL(string: urlString) {
            wv.load(URLRequest(url: url))
        }
        self.webView = wv
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(urlString: $urlString)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var urlString: String
        init(urlString: Binding<String>) { self._urlString = urlString }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let u = webView.url?.absoluteString {
                urlString = u
            }
        }
    }
}

// MARK: - AX inspector panel

struct AXInspectorView: View {
    let tree: AXElement?
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "view.accessibility")
                    .foregroundStyle(themeManager.theme.accent)
                Text("Accessibility tree")
                    .font(.headline)
                    .foregroundStyle(themeManager.theme.textPrimary)
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()
            .background(themeManager.theme.surfaceElevated)

            Divider().background(themeManager.theme.divider)

            ScrollView {
                if let tree {
                    AXTreeNodeView(node: tree, depth: 0)
                } else {
                    Text("No accessibility data available.")
                        .foregroundStyle(themeManager.theme.textSecondary)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.theme.background)
        }
        .background(themeManager.theme.background)
        .frame(minWidth: 560, minHeight: 400)
    }
}

struct AXTreeNodeView: View {
    let node: AXElement
    let depth: Int
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: iconFor(role: node.role))
                    .foregroundStyle(themeManager.theme.textSecondary)
                    .frame(width: 16)
                Text(node.role)
                    .fontWeight(.medium)
                    .foregroundStyle(themeManager.theme.textPrimary)
                if let title = node.title, !title.isEmpty {
                    Text("“\(title)”")
                        .fontWeight(.semibold)
                        .foregroundStyle(themeManager.theme.accent)
                }
                if let value = node.value, !value.isEmpty {
                    Text("= \(value)")
                        .font(.caption)
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
                if node.focused {
                    Text("focused")
                        .font(.caption2)
                        .padding(2)
                        .background(themeManager.theme.accent.opacity(0.2))
                        .foregroundStyle(themeManager.theme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                if !node.enabled {
                    Text("disabled")
                        .font(.caption2)
                        .foregroundStyle(themeManager.theme.textMuted)
                }
                if let frame = node.frame {
                    Text("\(Int(frame.origin.x)),\(Int(frame.origin.y)) \(Int(frame.size.width))x\(Int(frame.size.height))")
                        .font(.caption2)
                        .foregroundStyle(themeManager.theme.textMuted)
                }
                Spacer(minLength: 8)
                Button("Click") {
                    if let frame = node.frame {
                        AXController.shared.click(at: CGPoint(x: frame.midX, y: frame.midY))
                    }
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .disabled(!node.enabled || node.frame == nil)
                .foregroundStyle(themeManager.theme.textMuted)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(depth % 2 == 0 ? Color.clear : themeManager.theme.surface.opacity(0.3))

            ForEach(node.children) { child in
                AXTreeNodeView(node: child, depth: depth + 1)
                    .padding(.leading, 18)
            }
        }
    }

    private func iconFor(role: String) -> String {
        switch role {
        case "AXButton": return "pushpin"
        case "AXTextField", "AXSearchField": return "textformat"
        case "AXStaticText": return "text.alignleft"
        case "AXWindow": return "window"
        case "AXApplication": return "app.dashed"
        case "AXMenu": return "list.dash"
        case "AXLink": return "link"
        default: return "circle"
        }
    }
}
