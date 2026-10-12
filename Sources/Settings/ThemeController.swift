import AppKit

/// Controls application-wide appearance (Aqua vs. Dark Aqua vs. System default).
@MainActor
enum ThemeController {
    static func apply(theme: AppTheme) {
        let app = NSApplication.shared
        switch theme {
        case .system:
            app.appearance = nil
        case .light:
            app.appearance = NSAppearance(named: .aqua)
        case .dark:
            app.appearance = NSAppearance(named: .darkAqua)
        }
    }

    static func applyStoredTheme() {
        apply(theme: AppSettings.storedTheme)
    }
}
