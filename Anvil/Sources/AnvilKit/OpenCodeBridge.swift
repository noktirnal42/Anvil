// MARK: - OpenCode bridge (hybrid phase 1: embeds the MIT opencode CLI server)

import Foundation

/// Thin bridge to the bundled OpenCode CLI server. The CLI binary is embedded
/// in the app bundle at `Resources/opencode-cli` (see script/embed-opencode-cli.sh)
/// and spawned as a local subprocess; Anvil speaks to it over its native IPC.
@MainActor
public final class OpenCodeBridge: ObservableObject {
    public static let shared = OpenCodeBridge()
    @Published public var isServerRunning = false
    public var serverEndpoint: String?

    private var serverProcess: Process?
    private init() {}

    public func start() async {
        // Resolve the bundled opencode CLI binary.
        guard let cliURL = cliBinaryURL() else {
            print("[Anvil] opencode-cli binary not found in bundle. Run Anvil/script/embed-opencode-cli.sh to build and embed it.")
            return
        }
        let process = Process()
        process.executableURL = cliURL
        process.arguments = ["serve", "--port", "0"]   // port 0 = OS-assigned
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            serverProcess = process
            isServerRunning = true
            print("[Anvil] OpenCode bridge started (pid \(process.processIdentifier))")
        } catch {
            print("[Anvil] Failed to start OpenCode bridge: \(error)")
        }
    }

    public func stop() {
        serverProcess?.terminate()
        serverProcess = nil
        isServerRunning = false
    }

    /// Locate the embedded opencode-cli binary. In a dev run it lives in the
    /// package's Resources folder; in a shipped .app it's under Contents/Resources.
    private func cliBinaryURL() -> URL? {
        // 1) Dev: Sources/AnvilApp/Resources/opencode-cli
        let devURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Sources/AnvilApp
            .appendingPathComponent("Resources/opencode-cli")
        if FileManager.default.fileExists(atPath: devURL.path) {
            return devURL
        }
        // 2) Bundled app: Contents/Resources/opencode-cli
        if let res = Bundle.main.resourceURL?.appendingPathComponent("opencode-cli"),
           FileManager.default.fileExists(atPath: res.path) {
            return res
        }
        // 3) Fallback: cwd-relative
        let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources/opencode-cli")
        if FileManager.default.fileExists(atPath: cwdURL.path) {
            return cwdURL
        }
        return nil
    }
}
