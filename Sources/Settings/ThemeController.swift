import AppKit

/// Controls application-wide appearance (Aqua vs. Dark Aqua vs. System default).
@MainActor
enum ThemeController {
    static func apply(theme: AppTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    static func applyStoredTheme() {
        apply(theme: AppSettings.storedTheme)
    }
}
