// MARK: - OpenCode bridge (hybrid phase 1: embeds the MIT opencode CLI server)

import Foundation

/// Thin bridge to the bundled OpenCode CLI server. In phase 1 we shell out to / spawn
/// the opencode server and speak to it over its local IPC/HTTP. Phase 2 replaces this
/// with a pure-Swift session engine.
@MainActor
public final class OpenCodeBridge: ObservableObject {
    public static let shared = OpenCodeBridge()
    @Published public var isServerRunning = false
    public var serverEndpoint: String?   // e.g. http://127.0.0.1:PORT

    private var serverProcess: Process?
    private init() {}

    public func start() async {
        // Locate the bundled opencode CLI binary (ship it in Resources/opencode-cli; resolved
        // from the app bundle at runtime in phase 1 packaging).
        guard let cliURL = Bundle.main.url(forResource: "opencode-cli", withExtension: nil) else {
            print("[Anvil] opencode-cli binary not found in bundle (phase 1 stub)")
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
            // In a real impl, read the assigned port from stdout and set serverEndpoint
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
}
