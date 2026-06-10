import SwiftUI

/// The set of structural-edit actions the front window exposes to menu commands.
/// Published through `FocusedValues` so the Operations menu can drive whichever
/// document is frontmost.
@MainActor
struct EditorActions {
    let addSibling: () -> Void
    let addChild: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void
    let copy: () -> Void
    let cut: () -> Void
    let paste: () -> Void
    let sortKeys: () -> Void
    let canEditSelection: Bool
    let canAddChild: Bool
    let canDelete: Bool
    let canPaste: Bool
    let canSortKeys: Bool
}

extension FocusedValues {
    @Entry var editorActions: EditorActions?
}
