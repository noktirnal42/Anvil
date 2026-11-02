// MARK: - Theme selector (mini picker for the toolbar)

import SwiftUI
import AnvilKit

struct ThemePicker: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Menu {
            ForEach(AnvilTheme.all) { theme in
                Button(theme.displayName) {
                    themeManager.select(theme)
                }
            }
        } label: {
            Label("Theme", systemImage: "paintbrush")
                .labelStyle(.iconOnly)
        }
        .menuIndicator(.hidden)
        .help("Choose a theme")
    }
}
