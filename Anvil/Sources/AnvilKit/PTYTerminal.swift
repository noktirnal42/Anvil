// MARK: - Native PTY terminal (Darwin posix_openpt + Foundation Process/FileHandle)

import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// A single terminal session running the user's shell inside a pseudo-terminal.
/// All pty I/O is delivered on the main actor so SwiftUI can render output live.
@MainActor
public final class PTYTerminal: NSObject, ObservableObject {
    public static let shared = PTYTerminal()
    private override init() {}

    /// Emitted output from the pty (raw bytes decoded as UTF-8, lossy).
    @Published public var output: AttributedString = AttributedString("")
    /// Parses escape sequences out of the raw stream; state carries across reads.
    private var ansi = ANSIStream()

    /// Whether a shell is currently running.
    @Published public var isRunning: Bool = false

    /// The shell's exit code, if it has terminated.
    @Published public var exitCode: Int? = nil

    // File descriptors / process
    private var masterFD: Int32 = -1
    private var slaveFD: Int32 = -1
    private var readHandle: FileHandle?
    private var process: Process?

    /// Spawn the user's default shell in a new pty.
    public func start() {
        guard masterFD == -1 else { return }  // already running

        #if canImport(Darwin)
        let fd = posix_openpt(O_RDWR)
        guard fd >= 0 else {
            print("[Anvil] posix_openpt failed")
            return
        }
        masterFD = fd

        grantpt(masterFD)
        unlockpt(masterFD)

        var slaveNameBuffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard ptsname_r(masterFD, &slaveNameBuffer, slaveNameBuffer.count) == 0 else {
            print("[Anvil] ptsname_r failed")
            Darwin.close(masterFD)
            masterFD = -1
            return
        }
        let slavePath = String(cString: slaveNameBuffer)

        slaveFD = open(slavePath, O_RDWR)
        guard slaveFD >= 0 else {
            print("[Anvil] open slave failed")
            Darwin.close(masterFD)
            masterFD = -1
            return
        }

        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = []
        let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: false)
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        self.process = process

        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in
                self?.isRunning = false
                self?.exitCode = Int(process.terminationStatus)
                self?.closeFd()
            }
        }

        do {
            try process.run()
        } catch {
            print("[Anvil] process.run failed: \(error)")
            closeFd()
            return
        }

        // Parent no longer needs the slave fd (child duped it to stdio)
        Darwin.close(slaveFD)
        slaveFD = -1

        isRunning = true
        exitCode = nil

        // Watch for output on the master fd via FileHandle readability handler
        let readHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: false)
        self.readHandle = readHandle
        readHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                let chunk = String(data: data, encoding: .utf8) ?? String(decoding: data, as: Unicode.ASCII.self)
                Task { @MainActor in
                    guard let self else { return }
                    self.output += self.ansi.append(chunk)
                }
            } else {
                Task { @MainActor in
                    self?.closeFd()
                }
            }
        }
        #else
        print("[Anvil] PTY not available on this platform")
        #endif
    }

    /// Send text to the pty (keystrokes).
    public func write(_ text: String) {
        guard masterFD != -1 else { return }
        let data = text.data(using: .utf8)!
        _ = data.withUnsafeBytes { ptr in
            Darwin.write(masterFD, ptr.baseAddress, ptr.count)
        }
    }

    /// Send a signal (e.g. SIGINT for Ctrl-C, SIGTERM for stop).
    public func signal(_ sig: Int32) {
        #if canImport(Darwin)
        if sig == SIGINT {
            process?.interrupt()
        } else {
            process?.terminate()
        }
        #endif
    }

    public func stop() {
        process?.terminate()
        closeFd()
    }

    private func closeFd() {
        readHandle?.readabilityHandler = nil
        readHandle = nil
        if masterFD != -1 {
            Darwin.close(masterFD)
            masterFD = -1
        }
        if slaveFD != -1 {
            Darwin.close(slaveFD)
            slaveFD = -1
        }
        process = nil
        isRunning = false
    }

    public func clear() {
        output = AttributedString("")
        ansi = ANSIStream()
    }
}
