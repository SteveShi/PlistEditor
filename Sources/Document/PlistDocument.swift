import SwiftUI
import UniformTypeIdentifiers

/// The document model backing each editor window. It owns the live node tree,
/// the chosen serialization format, and the mirrored source-pane text. Because
/// editing relies on `UndoManager`, this is a `ReferenceFileDocument` rather
/// than a value-type `FileDocument`.
// The document is created on a background queue when opening a file, so it is
// not main-actor isolated. All mutation happens on the main thread at runtime.
final class PlistDocument: ReferenceFileDocument, @unchecked Sendable {
    typealias Snapshot = Data

    static var readableContentTypes: [UTType] {
        [.propertyList, .json, .xml, .plainText]
    }

    static var writableContentTypes: [UTType] {
        [.propertyList, .json, .xml, .plainText]
    }

    @Published var root: PlistNode
    @Published var format: PlistFormat
    @Published var sourceText: String = ""
    @Published var autoSyncText: Bool = true
    @Published var syncError: String?

    /// Per-node "View As" presentation overrides (display state, not persisted).
    @Published var viewAs: [PlistNode.ID: ValueFormatter] = [:]

    init() {
        root = PlistNode(kind: .dictionary([]))
        format = AppSettings.storedDefaultFormat
        regenerateSourceText()
    }

    // SwiftUI invokes this on a background queue, so it must be nonisolated; the
    // node tree it builds is non-isolated and only used on the main thread later.
    nonisolated required init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        let parsed = try PlistSerializer.parse(data)
        // OpenStep cannot be written back, so edit it as XML.
        let resolvedFormat = parsed.format.canWrite ? parsed.format : .xml
        self.root = parsed.root
        self.format = resolvedFormat
        self.sourceText = (try? PlistTextRenderer.text(from: parsed.root, format: resolvedFormat)) ?? ""
    }

    func snapshot(contentType: UTType) throws -> Data {
        try PlistSerializer.data(from: root, format: format, jsonIndented: AppSettings.storedJSONSaveIndented)
    }

    nonisolated func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: snapshot)
    }

    // MARK: Source text synchronization

    /// Regenerates the source text from the current outline state.
    func regenerateSourceText() {
        if let text = try? PlistTextRenderer.text(from: root, format: format) {
            sourceText = text
        }
    }

    /// Called after every structural or value mutation of the outline.
    func didMutateOutline() {
        if autoSyncText { regenerateSourceText() }
    }

    /// Reparses the source text and replaces the outline ("Sync outline").
    @MainActor
    func syncOutlineFromText(undoManager: UndoManager?) {
        do {
            let parsed = try PlistSerializer.parseText(sourceText)
            setRoot(parsed.root, format: format, undoManager: undoManager)
            syncError = nil
        } catch {
            syncError = error.localizedDescription
        }
    }

    @MainActor
    func setRoot(_ newRoot: PlistNode, format newFormat: PlistFormat, undoManager: UndoManager?) {
        let oldRoot = root
        let oldFormat = format
        root = newRoot
        format = newFormat
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.setRoot(oldRoot, format: oldFormat, undoManager: undoManager)
            }
        }
        regenerateSourceText()
    }

    @MainActor
    func setFormat(_ newFormat: PlistFormat, undoManager: UndoManager?) {
        guard newFormat != format else { return }
        let oldFormat = format
        format = newFormat
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.setFormat(oldFormat, undoManager: undoManager)
            }
        }
        regenerateSourceText()
    }
}
