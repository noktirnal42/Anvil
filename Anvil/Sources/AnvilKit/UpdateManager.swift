// MARK: - Sparkle auto-update manager

import Foundation

/// Checks for updates against a Sparkle appcast hosted on GitHub Releases.
@MainActor
public final class UpdateManager: ObservableObject {
    public static let shared = UpdateManager()
    private init() {}

    @Published public var isChecking = false
    @Published public var latestVersion: String?
    @Published public var releaseNotesLink: String?
    @Published public var downloadURL: URL?
    @Published public var updateError: String?

    /// The appcast URL (Sparkle-compatible RSS with enclosure). Point this at
    /// your GitHub releases page or a self-hosted appcast.
    public var appcastURL: URL? {
        URL(string: "https://github.com/noktirnal42/Anvil/releases.atom")
    }

    public func checkForUpdates() {
        guard let url = appcastURL else { return }
        isChecking = true
        updateError = nil
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            Task { @MainActor in
                self.isChecking = false
                if let error {
                    self.updateError = error.localizedDescription
                    return
                }
                guard let data, let text = String(data: data, encoding: .utf8) else {
                    self.updateError = "invalid appcast"
                    return
                }
                self.latestVersion = self.firstMatch(in: text, pattern: #"sparkle:version="([^"]+)""#)
                self.releaseNotesLink = self.firstMatch(in: text, pattern: #"sparkle:releaseNotesLink="([^"]+)""#)
                if let enclosureURL = self.firstMatch(in: text, pattern: #"url="([^"]+)"[^>]*sparkle:version"#) {
                    self.downloadURL = URL(string: enclosureURL)
                }
            }
        }.resume()
    }

    private func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
