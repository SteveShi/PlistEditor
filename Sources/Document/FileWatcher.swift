import Foundation

/// Monitors a file on disk for external modifications using a GCD
/// `DispatchSource`. When a write, rename, or delete event is detected the
/// `onChange` closure is called on the main queue.
///
/// Usage:
/// ```swift
/// let watcher = FileWatcher(url: fileURL) { [weak self] in
///     self?.handleExternalChange()
/// }
/// // … later …
/// watcher.stop()
/// ```
///
/// The watcher automatically reopens the file descriptor when the file is
/// replaced (common pattern: write-to-temp → rename), so it survives most
/// external editor save strategies.
final class FileWatcher: @unchecked Sendable {

    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let url: URL
    private let onChange: @MainActor @Sendable () -> Void

    /// Creates and immediately starts watching `url`.
    init(url: URL, onChange: @escaping @MainActor @Sendable () -> Void) {
        self.url = url
        self.onChange = onChange
        startWatching()
    }

    deinit {
        stop()
    }

    /// Stops monitoring. Safe to call multiple times.
    func stop() {
        source?.cancel()
        source = nil
        closeDescriptor()
    }

    // MARK: Private

    private func startWatching() {
        stop()

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        fileDescriptor = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .global(qos: .utility)
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            let flags = src.data
            DispatchQueue.main.async {
                Task { @MainActor in
                    self.onChange()
                }
            }
            // If the file was deleted or replaced, re-arm the watcher on the
            // (possibly new) inode so we keep receiving events.
            if flags.contains(.delete) || flags.contains(.rename) {
                self.restartAfterReplace()
            }
        }

        src.setCancelHandler { [weak self] in
            self?.closeDescriptor()
        }

        source = src
        src.resume()
    }

    /// Re-opens the file descriptor after a delete/rename cycle (atomic save).
    private func restartAfterReplace() {
        // Small delay so the replacing process finishes moving the new file.
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startWatching()
        }
    }

    private func closeDescriptor() {
        guard fileDescriptor >= 0 else { return }
        close(fileDescriptor)
        fileDescriptor = -1
    }
}
