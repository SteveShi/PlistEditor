import SwiftUI

@main
struct PlistEditorApp: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var updater = Updater()

    /// Installing `AutosaveDocumentController` before anything accesses
    /// `NSDocumentController.shared` makes it the app-wide shared instance.
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        LanguageController.applyStoredLanguage()
    }

    var body: some Scene {
        DocumentGroup(newDocument: { PlistDocument() }) { configuration in
            ContentView(document: configuration.document, fileURL: configuration.fileURL)
        }
        .commands {
            OperationsCommands()
            CommandGroup(after: .appInfo) {
                Button("menu.checkForUpdates") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
            CommandGroup(after: .windowList) {
                Button("browser.title") {
                    openWindow(id: "preferences-browser")
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }

        Window("browser.title", id: "preferences-browser") {
            PreferenceBrowserView()
        }
        .defaultSize(width: 800, height: 500)
    }
}

/// Minimal delegate whose sole job is to configure `NSDocumentController.shared`
/// properties (like `autosavingDelay`) dynamically after the app launches.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var observation: (any NSObjectProtocol)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupAutosaveDelay()
        
        observation = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupAutosaveDelay()
        }
    }

    private func setupAutosaveDelay() {
        let enabled = UserDefaults.standard.bool(forKey: SettingsKey.enableAutosaving)
        // macOS default autosave delay is 30.0 seconds. If disabled, set it to 0.0.
        NSDocumentController.shared.autosavingDelay = enabled ? 30.0 : 0.0
    }

    /// Controls whether activating the app with no open windows creates a new
    /// untitled document, respecting the user's "When activated" preference.
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let action = ActivateAction(
            rawValue: UserDefaults.standard.string(forKey: SettingsKey.activateAction) ?? ""
        ) ?? .createDocument
        return action == .createDocument
    }
}

