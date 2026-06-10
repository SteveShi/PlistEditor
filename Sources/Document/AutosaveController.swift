import AppKit

/// A custom `NSDocumentController` that dynamically controls whether autosaving
/// is active based on the user's preference (`enableAutosaving` in Settings).
///
/// When autosaving is disabled the `autosavingDelay` is set to 0, which
/// prevents the system timer from triggering periodic saves. When enabled, the
/// default system interval (~30 s on macOS) is used.
///
/// Install this controller early (before `NSDocumentController.shared` is first
/// accessed) so that it becomes the app-wide shared instance.
@MainActor
final class AutosaveDocumentController: NSDocumentController {

    /// KVO observation token for the `UserDefaults` key.
    private var observation: (any NSObjectProtocol)?

    override init() {
        super.init()
        startObservingPreference()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        startObservingPreference()
    }

    // MARK: Autosaving override

    override var autosavingDelay: TimeInterval {
        get {
            let enabled = UserDefaults.standard.object(forKey: SettingsKey.enableAutosaving) as? Bool ?? false
            return enabled ? super.autosavingDelay : 0
        }
        set { super.autosavingDelay = newValue }
    }

    // MARK: Private

    private func startObservingPreference() {
        observation = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Poke the property so NSDocumentController re-evaluates the delay.
                guard let self else { return }
                self.autosavingDelay = self.autosavingDelay
            }
        }
    }
}
