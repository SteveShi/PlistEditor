# Specification: App Theme Selection (System, Light, Dark)

**Date**: 2026-10-13  
**Status**: Approved  
**Author**: Steve Shi / 轩楝  
**Target Version**: 1.1.7  

---

## 1. Overview & Objective

Add an application-wide theme switching feature to PlistEditor, allowing users to toggle between:
- **System (`system`)**: Follow macOS system appearance automatically.
- **Light (`light`)**: Force light appearance (Aqua).
- **Dark (`dark`)**: Force dark appearance (Dark Aqua).

The control will be rendered as a segmented picker at the top of the **Display** (`settings.tab.display`) tab in the Settings window (⌘,). Theme changes will take effect immediately across all windows, titlebars, toolbars, dialogs, and embedded AppKit text editors without requiring an application restart.

---

## 2. Architecture & Data Flow

```
+-------------------------------------------------------------------+
|                        UserDefaults ("display.theme")             |
+-------------------------------------------------------------------+
                                  ^
                                  | get/set
+---------------------------------+---------------------------------+
|                       AppSettings.shared.theme                    |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
|                       ThemeController.apply()                     |
|                                                                   |
|   - system -> NSApp.appearance = nil                              |
|   - light  -> NSApp.appearance = NSAppearance(named: .aqua)       |
|   - dark   -> NSApp.appearance = NSAppearance(named: .darkAqua)   |
+-------------------------------------------------------------------+
          |                                               |
          v                                               v
+-----------------------------+               +---------------------+
|      SwiftUI Windows        |               |   AppKit Views      |
|  (.preferredColorScheme)    |               |  (SourceTextView)   |
|   - DocumentGroup           |               |  - NSColor.textColor|
|   - SettingsView            |               |  - Responds to      |
|   - PreferenceBrowserView   |               |    appearance change|
+-----------------------------+               +---------------------+
```

---

## 3. Detailed Component Design

### 3.1 `AppTheme` Enum (`Sources/Settings/AppTheme.swift`)
An enum defining the three available appearances:
```swift
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
```

### 3.2 `ThemeController` (`Sources/Settings/ThemeController.swift`)
Manages the application-level `NSAppearance`:
```swift
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
        let stored = AppSettings.storedTheme
        apply(theme: stored)
    }
}
```

### 3.3 `AppSettings` Integration (`Sources/Settings/AppSettings.swift`)
- Add key:
  ```swift
  static let theme = "display.theme"
  ```
- Add static nonisolated reader for startup and background tasks:
  ```swift
  nonisolated static var storedTheme: AppTheme {
      let raw = UserDefaults.standard.string(forKey: SettingsKey.theme) ?? ""
      return AppTheme(rawValue: raw) ?? .system
  }
  ```
- Add published property on `@MainActor AppSettings`:
  ```swift
  var theme: AppTheme {
      get { Self.storedTheme }
      set {
          set(newValue.rawValue, SettingsKey.theme)
          ThemeController.apply(theme: newValue)
      }
  }
  ```

### 3.4 Settings UI (`Sources/Settings/SettingsView.swift`)
At the very top of `DisplaySettingsTab`:
```swift
Section("settings.display.theme") {
    Picker("settings.display.theme", selection: $settings.theme) {
        ForEach(AppTheme.allCases) { theme in
            Label(theme.localizationKey, systemImage: theme.systemImage)
                .tag(theme)
        }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
}
```

### 3.5 App Lifecycle (`Sources/App/PlistEditorApp.swift`)
- In `init()`:
  ```swift
  init() {
      LanguageController.applyStoredLanguage()
      ThemeController.applyStoredTheme()
  }
  ```
- Attach `.preferredColorScheme(settings.theme.colorScheme)` to `DocumentGroup`, `Settings`, and `Window("preferences-browser")`.

### 3.6 AppKit View Styling (`Sources/Views/Source/SourceTextView.swift`)
- When `NSApp.appearance` changes, `NSTextView` receives appearance invalidation. In `updateNSView`, include `settings.theme` or appearance observation into `styleKey` so that syntax highlighting and `NSColor.textColor` re-render cleanly on theme switches.

### 3.7 Localization (`Resources/Localizable.xcstrings`)
Add keys for `en` and `zh-Hans`:
- `settings.display.theme`: `"Theme"` / `"主题"`
- `settings.display.theme.system`: `"System"` / `"跟随系统"`
- `settings.display.theme.light`: `"Light"` / `"浅色"`
- `settings.display.theme.dark`: `"Dark"` / `"深色"`

---

## 4. Verification & Acceptance Criteria

1. **Compilation**: `xcodegen generate && xcodebuild build` passes cleanly with zero warnings or errors.
2. **Display Settings**: Segmented picker appears at top of Settings -> Display tab showing "System", "Light", "Dark" with icons.
3. **Instant Switching**:
   - Selecting "Light" immediately turns all windows, outline tables, text views, and inspector panes to light mode.
   - Selecting "Dark" immediately turns all windows to dark mode.
   - Selecting "System" conforms to macOS System Settings -> Appearance immediately.
4. **Persistence**: Relaunching the app preserves the selected theme.
5. **Localization**: English and Simplified Chinese show respective strings.
