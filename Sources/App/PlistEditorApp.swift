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

/// Minimal delegate whose sole job is to install `AutosaveDocumentController`
/// very early in the app lifecycle, before `NSDocumentController.shared` is
/// first queried by `DocumentGroup`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AutosaveDocumentController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Creating an NSDocumentController subclass automatically registers it
        // as the shared instance when done before any other access.
        controller = AutosaveDocumentController()
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

