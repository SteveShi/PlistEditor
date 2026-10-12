import SwiftUI

/// The available visual themes for the application.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var localizationKey: LocalizedStringKey {
        switch self {
        case .system: return "settings.display.theme.system"
        case .light: return "settings.display.theme.light"
        case .dark: return "settings.display.theme.dark"
        }
    }
}
