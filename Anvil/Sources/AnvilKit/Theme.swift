// MARK: - Theme engine (SPEC: warm minimal / graphite / terminal heritage / matrix techy)

import SwiftUI

/// A complete visual theme for Anvil.
public struct AnvilTheme: Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let displayName: String
    public let accent: Color
    public let secondaryAccent: Color
    public let background: Color
    public let surface: Color
    public let surfaceElevated: Color
    public let textPrimary: Color
    public let textSecondary: Color
    public let textMuted: Color
    public let border: Color
    public let divider: Color
    public let chatBubbleUser: Color
    public let chatBubbleAssistant: Color
    public let codeBlockBackground: Color
    public let terminalBackground: Color
    public let terminalText: Color
    public let selection: Color
    public let error: Color
    public let warning: Color
    public let success: Color
    public let ambientGlyph: Color?   // Matrix falling-glyph ambient color, nil = none
    public let scanline: Bool          // CRT phosphor scanlines (matrix techy)
    public let glow: Bool              // accent glow

    public static let all: [AnvilTheme] = [
        .warmMinimal,
        .graphite,
        .terminalHeritage,
        .matrixTechy,
    ]

    // MARK: - Presets

    public static let warmMinimal = AnvilTheme(
        id: "warm-minimal",
        displayName: "Warm Minimal",
        accent: Color(red: 0.78, green: 0.56, blue: 0.36),   // warm clay
        secondaryAccent: Color(red: 0.92, green: 0.74, blue: 0.52),
        background: Color(red: 0.96, green: 0.94, blue: 0.90), // parchment
        surface: Color.white,
        surfaceElevated: Color(red: 0.99, green: 0.97, blue: 0.92),
        textPrimary: Color(red: 0.20, green: 0.16, blue: 0.12),
        textSecondary: Color(red: 0.42, green: 0.36, blue: 0.30),
        textMuted: Color(red: 0.62, green: 0.56, blue: 0.50),
        border: Color(red: 0.88, green: 0.82, blue: 0.72),
        divider: Color(red: 0.93, green: 0.88, blue: 0.78),
        chatBubbleUser: Color(red: 0.78, green: 0.56, blue: 0.36),
        chatBubbleAssistant: Color.white,
        codeBlockBackground: Color(red: 0.94, green: 0.91, blue: 0.85),
        terminalBackground: Color(red: 0.97, green: 0.95, blue: 0.90),
        terminalText: Color(red: 0.20, green: 0.16, blue: 0.12),
        selection: Color(red: 0.78, green: 0.56, blue: 0.36).opacity(0.35),
        error: Color(red: 0.78, green: 0.30, blue: 0.30),
        warning: Color(red: 0.82, green: 0.56, blue: 0.18),
        success: Color(red: 0.34, green: 0.62, blue: 0.34),
        ambientGlyph: nil,
        scanline: false,
        glow: false
    )

    public static let graphite = AnvilTheme(
        id: "graphite",
        displayName: "Graphite",
        accent: Color(red: 0.55, green: 0.60, blue: 0.68),    // slate blue-gray
        secondaryAccent: Color(red: 0.72, green: 0.78, blue: 0.84),
        background: Color(red: 0.10, green: 0.11, blue: 0.13),
        surface: Color(red: 0.16, green: 0.17, blue: 0.20),
        surfaceElevated: Color(red: 0.20, green: 0.21, blue: 0.25),
        textPrimary: Color.white,
        textSecondary: Color(red: 0.82, green: 0.84, blue: 0.88),
        textMuted: Color(red: 0.52, green: 0.54, blue: 0.58),
        border: Color(red: 0.28, green: 0.29, blue: 0.33),
        divider: Color(red: 0.22, green: 0.23, blue: 0.26),
        chatBubbleUser: Color(red: 0.55, green: 0.60, blue: 0.68),
        chatBubbleAssistant: Color(red: 0.20, green: 0.21, blue: 0.25),
        codeBlockBackground: Color(red: 0.13, green: 0.14, blue: 0.16),
        terminalBackground: Color(red: 0.08, green: 0.09, blue: 0.11),
        terminalText: Color(red: 0.88, green: 0.90, blue: 0.94),
        selection: Color(red: 0.55, green: 0.60, blue: 0.68).opacity(0.4),
        error: Color(red: 0.90, green: 0.40, blue: 0.40),
        warning: Color(red: 0.94, green: 0.66, blue: 0.28),
        success: Color(red: 0.44, green: 0.72, blue: 0.44),
        ambientGlyph: nil,
        scanline: false,
        glow: true
    )

    public static let terminalHeritage = AnvilTheme(
        id: "terminal-heritage",
        displayName: "Terminal Heritage",
        accent: Color(red: 0.12, green: 0.88, blue: 0.55),    // terminal green
        secondaryAccent: Color(red: 0.30, green: 0.96, blue: 0.70),
        background: Color(red: 0.01, green: 0.01, blue: 0.02),
        surface: Color(red: 0.06, green: 0.06, blue: 0.08),
        surfaceElevated: Color(red: 0.09, green: 0.09, blue: 0.12),
        textPrimary: Color(red: 0.90, green: 0.94, blue: 0.90),
        textSecondary: Color(red: 0.56, green: 0.60, blue: 0.56),
        textMuted: Color(red: 0.30, green: 0.33, blue: 0.30),
        border: Color(red: 0.18, green: 0.22, blue: 0.18),
        divider: Color(red: 0.12, green: 0.14, blue: 0.12),
        chatBubbleUser: Color(red: 0.12, green: 0.88, blue: 0.55),
        chatBubbleAssistant: Color(red: 0.06, green: 0.06, blue: 0.08),
        codeBlockBackground: Color(red: 0.04, green: 0.04, blue: 0.06),
        terminalBackground: Color.black,
        terminalText: Color(red: 0.12, green: 0.88, blue: 0.55),
        selection: Color(red: 0.12, green: 0.88, blue: 0.55).opacity(0.35),
        error: Color(red: 0.94, green: 0.30, blue: 0.30),
        warning: Color(red: 0.96, green: 0.70, blue: 0.20),
        success: Color(red: 0.12, green: 0.88, blue: 0.55),
        ambientGlyph: nil,
        scanline: true,
        glow: true
    )

    public static let matrixTechy = AnvilTheme(
        id: "matrix-techy",
        displayName: "Matrix Techy",
        accent: Color(red: 0.0, green: 1.0, blue: 0.4),       // matrix green
        secondaryAccent: Color(red: 0.4, green: 1.0, blue: 0.6),
        background: Color(red: 0.005, green: 0.01, blue: 0.008),
        surface: Color(red: 0.01, green: 0.02, blue: 0.015),
        surfaceElevated: Color(red: 0.015, green: 0.03, blue: 0.02),
        textPrimary: Color(red: 0.2, green: 1.0, blue: 0.5),
        textSecondary: Color(red: 0.1, green: 0.6, blue: 0.3),
        textMuted: Color(red: 0.05, green: 0.3, blue: 0.15),
        border: Color(red: 0.0, green: 0.5, blue: 0.2),
        divider: Color(red: 0.0, green: 0.25, blue: 0.1),
        chatBubbleUser: Color(red: 0.0, green: 1.0, blue: 0.4).opacity(0.15),
        chatBubbleAssistant: Color(red: 0.01, green: 0.02, blue: 0.015),
        codeBlockBackground: Color(red: 0.008, green: 0.016, blue: 0.012),
        terminalBackground: Color.black,
        terminalText: Color(red: 0.0, green: 1.0, blue: 0.4),
        selection: Color(red: 0.0, green: 1.0, blue: 0.4).opacity(0.3),
        error: Color(red: 1.0, green: 0.15, blue: 0.2),
        warning: Color(red: 1.0, green: 0.75, blue: 0.1),
        success: Color(red: 0.0, green: 1.0, blue: 0.4),
        ambientGlyph: Color(red: 0.0, green: 0.4, blue: 0.15),
        scanline: true,
        glow: true
    )
}

/// Theme manager — persisted selection, supplied to the view hierarchy via
/// `.environmentObject`. Main-actor isolated because it drives SwiftUI rendering.
@MainActor
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    @Published public var theme: AnvilTheme

    private let defaultsKey = "AnvilThemeSelection"

    private init() {
        if let stored = UserDefaults.standard.string(forKey: defaultsKey),
           let theme = AnvilTheme.all.first(where: { $0.id == stored }) {
            self.theme = theme
        } else {
            self.theme = .warmMinimal
        }
    }

    public func select(_ theme: AnvilTheme) {
        self.theme = theme
        UserDefaults.standard.set(theme.id, forKey: defaultsKey)
    }
}

public extension View {
    func anvilTheme() -> some View {
        environmentObject(ThemeManager.shared)
    }
}
