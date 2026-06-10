import SwiftUI

enum SettingsKey {
    static let language = "app.language"

    static let defaultFormat = "general.defaultFormat"
    static let activateAction = "general.activateAction"
    static let expandOnOpen = "general.expandOnOpen"
    static let enableAutosaving = "general.enableAutosaving"
    static let defaultClass = "general.defaultClass"
    static let askToRevert = "general.askToRevert"
    static let rememberFormatterByKey = "general.rememberFormatterByKey"
    static let returnEditsNextRow = "general.returnEditsNextRow"

    static let outlineFontName = "display.outlineFont.name"
    static let outlineFontSize = "display.outlineFont.size"
    static let textFontName = "display.textFont.name"
    static let textFontSize = "display.textFont.size"
    static let browserFontName = "display.browserFont.name"
    static let browserFontSize = "display.browserFont.size"
    static let sortCaseSensitive = "display.sort.caseSensitive"
    static let sortNumeric = "display.sort.numeric"
    static let colorXMLTags = "display.colorXMLTags"
    static let xmlTagColor = "display.xmlTagColor"
    static let jsonDisplayIndented = "display.json.displayIndented"
    static let jsonSaveIndented = "display.json.saveIndented"

    static let browsingExtensions = "browsing.extensions"
}

/// What the app does when activated with no open windows.
enum ActivateAction: String, CaseIterable, Sendable {
    case createDocument
    case doNothing
}

/// How much of a document to expand when it opens.
enum ExpandOnOpen: String, CaseIterable, Sendable {
    case rootOnly
    case allChildren
}

/// Application preferences, persisted in `UserDefaults`. Properties are computed
/// over `UserDefaults` so reads always reflect the latest value and there is no
/// load step; setters publish change notifications for SwiftUI.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultXMLTagColor = Color(.sRGB, red: 0.20, green: 0.67, blue: 0.86)

    private let defaults = UserDefaults.standard
    private init() {}

    private func set<T>(_ value: T, _ key: String) {
        objectWillChange.send()
        defaults.set(value, forKey: key)
    }

    private func bool(_ key: String, default fallback: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? fallback
    }

    // MARK: General

    var language: AppLanguage {
        get { AppLanguage.language(forID: defaults.string(forKey: SettingsKey.language)) }
        set { objectWillChange.send(); LanguageController.setLanguage(newValue) }
    }

    var defaultFormat: PlistFormat {
        get { PlistFormat(rawValue: defaults.string(forKey: SettingsKey.defaultFormat) ?? "") ?? .xml }
        set { set(newValue.rawValue, SettingsKey.defaultFormat) }
    }

    var activateAction: ActivateAction {
        get { ActivateAction(rawValue: defaults.string(forKey: SettingsKey.activateAction) ?? "") ?? .createDocument }
        set { set(newValue.rawValue, SettingsKey.activateAction) }
    }

    var expandOnOpen: ExpandOnOpen {
        get { ExpandOnOpen(rawValue: defaults.string(forKey: SettingsKey.expandOnOpen) ?? "") ?? .rootOnly }
        set { set(newValue.rawValue, SettingsKey.expandOnOpen) }
    }

    var enableAutosaving: Bool {
        get { bool(SettingsKey.enableAutosaving, default: false) }
        set { set(newValue, SettingsKey.enableAutosaving) }
    }

    var defaultClass: PlistType {
        get { PlistType(rawValue: defaults.string(forKey: SettingsKey.defaultClass) ?? "") ?? .string }
        set { set(newValue.rawValue, SettingsKey.defaultClass) }
    }

    var askToRevert: Bool {
        get { bool(SettingsKey.askToRevert, default: false) }
        set { set(newValue, SettingsKey.askToRevert) }
    }

    var rememberFormatterByKey: Bool {
        get { bool(SettingsKey.rememberFormatterByKey, default: false) }
        set { set(newValue, SettingsKey.rememberFormatterByKey) }
    }

    var returnEditsNextRow: Bool {
        get { bool(SettingsKey.returnEditsNextRow, default: false) }
        set { set(newValue, SettingsKey.returnEditsNextRow) }
    }

    // MARK: Display

    var outlineFont: FontSetting {
        get { font(SettingsKey.outlineFontName, SettingsKey.outlineFontSize, defaultSize: 13) }
        set { setFont(newValue, SettingsKey.outlineFontName, SettingsKey.outlineFontSize) }
    }

    var textFont: FontSetting {
        get { font(SettingsKey.textFontName, SettingsKey.textFontSize, defaultName: "Menlo", defaultSize: 12) }
        set { setFont(newValue, SettingsKey.textFontName, SettingsKey.textFontSize) }
    }

    var browserFont: FontSetting {
        get { font(SettingsKey.browserFontName, SettingsKey.browserFontSize, defaultSize: 13) }
        set { setFont(newValue, SettingsKey.browserFontName, SettingsKey.browserFontSize) }
    }

    var sortCaseSensitive: Bool {
        get { bool(SettingsKey.sortCaseSensitive, default: false) }
        set { set(newValue, SettingsKey.sortCaseSensitive) }
    }

    var sortNumeric: Bool {
        get { bool(SettingsKey.sortNumeric, default: false) }
        set { set(newValue, SettingsKey.sortNumeric) }
    }

    var colorXMLTags: Bool {
        get { bool(SettingsKey.colorXMLTags, default: true) }
        set { set(newValue, SettingsKey.colorXMLTags) }
    }

    var xmlTagColor: Color {
        get { Color(hex: defaults.string(forKey: SettingsKey.xmlTagColor) ?? "", default: Self.defaultXMLTagColor) }
        set { set(newValue.hexString, SettingsKey.xmlTagColor) }
    }

    var jsonDisplayIndented: Bool {
        get { bool(SettingsKey.jsonDisplayIndented, default: true) }
        set { set(newValue, SettingsKey.jsonDisplayIndented) }
    }

    var jsonSaveIndented: Bool {
        get { bool(SettingsKey.jsonSaveIndented, default: false) }
        set { set(newValue, SettingsKey.jsonSaveIndented) }
    }

    // MARK: Browsing

    var browsingExtensions: [String] {
        get { defaults.stringArray(forKey: SettingsKey.browsingExtensions) ?? ["plist", "json", "xml", "strings", "entitlements"] }
        set { set(newValue, SettingsKey.browsingExtensions) }
    }

    // MARK: Font helpers

    private func font(_ nameKey: String, _ sizeKey: String, defaultName: String = FontSetting.systemName, defaultSize: Double) -> FontSetting {
        let name = defaults.string(forKey: nameKey) ?? defaultName
        let size = defaults.object(forKey: sizeKey) as? Double ?? defaultSize
        return FontSetting(name: name, size: size)
    }

    private func setFont(_ font: FontSetting, _ nameKey: String, _ sizeKey: String) {
        objectWillChange.send()
        defaults.set(font.name, forKey: nameKey)
        defaults.set(font.size, forKey: sizeKey)
    }
}

/// Thread-safe accessors for the handful of settings read off the main actor
/// (during background file reads/writes). `UserDefaults` is itself thread-safe.
extension AppSettings {
    nonisolated static var storedDefaultFormat: PlistFormat {
        PlistFormat(rawValue: UserDefaults.standard.string(forKey: SettingsKey.defaultFormat) ?? "") ?? .xml
    }

    nonisolated static var storedJSONDisplayIndented: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.jsonDisplayIndented) as? Bool ?? true
    }

    nonisolated static var storedJSONSaveIndented: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.jsonSaveIndented) as? Bool ?? false
    }

    nonisolated static var storedSortCaseSensitive: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.sortCaseSensitive) as? Bool ?? false
    }

    nonisolated static var storedSortNumeric: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.sortNumeric) as? Bool ?? false
    }

    /// Compares two dictionary keys respecting the current sort preferences.
    nonisolated static func compareKeys(_ a: String, _ b: String) -> ComparisonResult {
        var options: String.CompareOptions = []
        if !storedSortCaseSensitive { options.insert(.caseInsensitive) }
        if storedSortNumeric { options.insert(.numeric) }
        return a.compare(b, options: options)
    }
}
