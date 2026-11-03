// MARK: - Git client (shells out to system git)

import Foundation

public enum GitError: LocalizedError, Sendable, Equatable {
    case notAGitRepository
    case commandFailed(String)
    case parseFailed(String)
    case noRepository

    public var errorDescription: String? {
        switch self {
        case .notAGitRepository:
            return "This folder is not inside a Git repository."
        case .commandFailed(let message):
            return message.isEmpty ? "git failed without a message." : message
        case .parseFailed(let detail):
            return "Could not read git output: \(detail)"
        case .noRepository:
            return "No repository is selected."
        }
    }
}

/// Thin wrapper around the system `git` binary. All operations run on a
/// background queue and return on the caller's context.
@MainActor
public final class GitClient: NSObject, ObservableObject {
    public static let shared = GitClient()
    private override init() {}

    private let queue = DispatchQueue(label: "ai.anvil.desktop.git", qos: .userInitiated)

    /// Run `git` in `workingDirectory` and return trimmed stdout.
    private func run(_ args: [String], in workingDirectory: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = workingDirectory

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: GitError.commandFailed(error.localizedDescription))
                    return
                }

                process.waitUntilExit()
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus != 0 {
                    let msg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "git exit \(process.terminationStatus)"
                    continuation.resume(throwing: GitError.commandFailed(msg))
                    return
                }
                let out = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                continuation.resume(returning: out)
            }
        }
    }

    // MARK: - Repo detection

    public func isGitRepository(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.appendingPathComponent(".git").path)
    }

    public func findRepositoryRoot(_ url: URL) async -> URL? {
        guard let root = try? await run(["rev-parse", "--show-toplevel"], in: url) else { return nil }
        return root.isEmpty ? nil : URL(fileURLWithPath: root)
    }

    // MARK: - Status

    public enum FileStatus: Sendable, Equatable, Hashable {
        case unmodified, added, modified, deleted, renamed, untracked, ignored, conflicted
    }

    public struct ChangedFile: Sendable, Equatable, Identifiable {
        public let id = UUID()
        public let path: String
        public let staged: FileStatus
        public let unstaged: FileStatus
    }

    public func status(_ workingDirectory: URL) async throws -> [ChangedFile] {
        let output = try await run(["status", "--porcelain=v1"], in: workingDirectory)
        guard !output.isEmpty else { return [] }
        return output.components(separatedBy: "\n").compactMap { line in
            guard line.count >= 3 else { return nil }
            let stagedCode = String(line[line.startIndex])
            let unstagedCode = String(line[line.index(after: line.startIndex)])
            // path starts after "XY " (or "XY  " for renames with score)
            var pathStart = line.index(line.startIndex, offsetBy: 3)
            if line.count > 3, line[line.index(line.startIndex, offsetBy: 2)] == " " {
                pathStart = line.index(line.startIndex, offsetBy: 3)
            }
            let path = String(line[pathStart...])
            return ChangedFile(path: path,
                             staged: statusCode(stagedCode),
                             unstaged: statusCode(unstagedCode))
        }
    }

    private func statusCode(_ code: String) -> FileStatus {
        switch code {
        case " ": return .unmodified
        case "A": return .added
        case "M": return .modified
        case "D": return .deleted
        case "R": return .renamed
        case "?": return .untracked
        case "!": return .ignored
        case "C": return .conflicted
        default: return .unmodified
        }
    }

    // MARK: - Diff

    public func diff(_ workingDirectory: URL, file: String, staged: Bool = false) async throws -> String {
        var args = ["diff"]
        if staged { args.append("--cached") }
        args.append("--")
        args.append(file)
        return try await run(args, in: workingDirectory)
    }

    public func diffAll(_ workingDirectory: URL, staged: Bool = false) async throws -> String {
        var args = ["diff"]
        if staged { args.append("--cached") }
        return try await run(args, in: workingDirectory)
    }

    // MARK: - Stage / unstage

    public func stage(_ workingDirectory: URL, files: [String]) async throws {
        guard !files.isEmpty else { return }
        var args = ["add"]
        args.append(contentsOf: files)
        _ = try await run(args, in: workingDirectory)
    }

    public func unstage(_ workingDirectory: URL, files: [String]) async throws {
        guard !files.isEmpty else { return }
        _ = try await run(["reset", "--"] + files, in: workingDirectory)
    }

    public func discard(_ workingDirectory: URL, files: [String]) async throws {
        guard !files.isEmpty else { return }
        _ = try await run(["checkout", "--"] + files, in: workingDirectory)
    }

    // MARK: - Commit

    public func commit(_ workingDirectory: URL, message: String) async throws {
        _ = try await run(["commit", "-m", message], in: workingDirectory)
    }

    // MARK: - Log

    public struct Commit: Sendable, Equatable, Identifiable {
        public let id = UUID()
        public let hash: String
        public let subject: String
        public let author: String
        public let date: Date
    }

    public func log(_ workingDirectory: URL, limit: Int = 20) async throws -> [Commit] {
        let output = try await run(["log", "--max-count", "\(limit)",
                                    "--pretty=format:%H%x09%s%x09%an%x09%ad", "--date=iso"], in: workingDirectory)
        guard !output.isEmpty else { return [] }
        return output.components(separatedBy: "\n").compactMap { line in
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 4 else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = formatter.date(from: parts[3]) ?? .distantPast
            return Commit(hash: parts[0], subject: parts[1], author: parts[2], date: date)
        }
    }

    // MARK: - Branches

    public func currentBranch(_ workingDirectory: URL) async throws -> String {
        try await run(["rev-parse", "--abbrev-ref", "HEAD"], in: workingDirectory)
    }
}
