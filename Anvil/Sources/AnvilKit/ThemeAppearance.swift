// MARK: - Theme appearance

import AppKit
import SwiftUI

extension AnvilTheme {
    /// True when the background is dark. System controls (button labels, text
    /// fields, menus) follow the window's colour scheme, so the app sets the
    /// scheme from this to keep their text readable on the theme background.
    public var isDark: Bool {
        let color = NSColor(background).usingColorSpace(.sRGB) ?? .white
        let luminance = 0.299 * color.redComponent
            + 0.587 * color.greenComponent
            + 0.114 * color.blueComponent
        return luminance < 0.5
    }
}
