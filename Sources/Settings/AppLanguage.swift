import SwiftUI
import AppKit

/// A selectable UI language. The list is data-driven so adding a future
/// localization only requires (1) a new entry here, (2) translations in
/// `Localizable.xcstrings`, and (3) the matching `.lproj` for system strings.
struct AppLanguage: Identifiable, Hashable, Sendable {
    /// Stored identifier and `AppleLanguages` code. `nil` means follow the system.
    let code: String?
    /// Endonym shown in the picker (in the language's own script).
    let nativeName: String

    var id: String { code ?? "system" }

    /// Title key for the "System" entry only; concrete languages use `nativeName`.
    static let system = AppLanguage(code: nil, nativeName: "")

    static let english = AppLanguage(code: "en", nativeName: "English")
    static let simplifiedChinese = AppLanguage(code: "zh-Hans", nativeName: "简体中文")

    /// All offered languages. Append new `AppLanguage` values here to expand.
    static let all: [AppLanguage] = [system, english, simplifiedChinese]

    static func language(forID id: String?) -> AppLanguage {
        all.first { $0.id == (id ?? "system") } ?? system
    }
}

enum LanguageController {
    private static let appleLanguagesKey = "AppleLanguages"

    /// Applies the stored language override to `AppleLanguages`. Call once at
    /// launch, before any UI is built.
    static func applyStoredLanguage() {
        let stored = UserDefaults.standard.string(forKey: SettingsKey.language)
        let language = AppLanguage.language(forID: stored)
        if let code = language.code {
            UserDefaults.standard.set([code], forKey: appleLanguagesKey)
        } else {
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
        }
    }

    /// Persists a new language choice. Takes effect on the next launch.
    static func setLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.id, forKey: SettingsKey.language)
        if let code = language.code {
            UserDefaults.standard.set([code], forKey: appleLanguagesKey)
        } else {
            UserDefaults.standard.removeObject(forKey: appleLanguagesKey)
        }
    }

    /// Relaunches the app so the new language takes effect.
    @MainActor
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
        NSApp.terminate(nil)
    }
}
