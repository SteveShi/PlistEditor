import SwiftUI

/// The Operations menu, mirroring the toolbar's structural-edit actions and
/// adding keyboard shortcuts. Driven by the frontmost window's `EditorActions`.
struct OperationsCommands: Commands {
    @FocusedValue(\.editorActions) private var actions

    var body: some Commands {
        CommandMenu("menu.operations") {
            Button("menu.newSibling") { actions?.addSibling() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(actions == nil)

            Button("menu.newChild") { actions?.addChild() }
                .keyboardShortcut(.return, modifiers: [.command, .option])
                .disabled(!(actions?.canAddChild ?? false))

            Button("menu.duplicate") { actions?.duplicate() }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(!(actions?.canEditSelection ?? false))

            Divider()

            Button("menu.copy") { actions?.copy() }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(actions == nil)

            Button("menu.cut") { actions?.cut() }
                .keyboardShortcut("x", modifiers: .command)
                .disabled(!(actions?.canEditSelection ?? false))

            Button("menu.paste") { actions?.paste() }
                .keyboardShortcut("v", modifiers: .command)
                .disabled(!(actions?.canPaste ?? false))

            Divider()

            Button("menu.sortKeys") { actions?.sortKeys() }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!(actions?.canSortKeys ?? false))

            Divider()

            Button("menu.delete") { actions?.delete() }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!(actions?.canDelete ?? false))
        }
    }
}
