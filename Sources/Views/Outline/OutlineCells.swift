import SwiftUI

/// Environment key for the "select next row" action, used to implement
/// the "Pressing return edits next row" preference.
private struct SelectNextRowKey: EnvironmentKey {
    static let defaultValue: (@Sendable (PlistNode.ID) -> Void)? = nil
}

extension EnvironmentValues {
    var selectNextRow: (@Sendable (PlistNode.ID) -> Void)? {
        get { self[SelectNextRowKey.self] }
        set { self[SelectNextRowKey.self] = newValue }
    }
}

/// A plain inline text field that commits its edit only on Return or when focus
/// leaves the field, so each edit produces a single undo step.
struct EditableTextField: View {
    let node: PlistNode
    let value: String
    var isEditable: Bool = true
    var isMonospaced: Bool = false
    let onCommit: (String) -> Void

    @State private var draft: String = ""
    @FocusState private var focused: Bool
    @Environment(\.selectNextRow) private var selectNextRow

    var body: some View {
        TextField(text: $draft, label: { EmptyView() })
            .textFieldStyle(.plain)
            .disabled(!isEditable)
            .focused($focused)
            .onSubmit {
                commit()
                if AppSettings.shared.returnEditsNextRow {
                    selectNextRow?(node.id)
                }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .onChange(of: value) { _, newValue in
                if !focused { draft = newValue }
            }
            .onAppear { draft = value }
    }

    private func commit() {
        if draft != value { onCommit(draft) }
    }
}

/// Applies `.draggable` only to movable rows (everything but the root).
private struct DraggableNode: ViewModifier {
    let id: UUID
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.draggable(DraggedNodeID(id: id))
        } else {
            content
        }
    }
}

/// Key column: indentation, disclosure chevron, and the editable key (or the
/// positional label for array items / the root).
struct KeyCell: View {
    let document: PlistDocument
    let node: PlistNode
    let undoManager: UndoManager?
    let isExpanded: Bool
    let toggle: () -> Void
    let definition: StructureDefinition?

    private var depth: Int {
        var depth = 0
        var parent = node.parent
        while parent != nil {
            depth += 1
            parent = parent?.parent
        }
        return depth
    }

    var body: some View {
        rowContent
            .modifier(DraggableNode(id: node.id, enabled: node.parent != nil))
            .dropDestination(for: DraggedNodeID.self) { items, _ in
                handleDrop(items.first)
            }
    }

    private var rowContent: some View {
        HStack(spacing: 2) {
            Color.clear.frame(width: CGFloat(depth) * 14)

            Group {
                if node.isContainer {
                    Button(action: toggle) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear
                }
            }
            .frame(width: 14)

            keyContent
        }
        .contentShape(Rectangle())
    }

    private func handleDrop(_ dragged: DraggedNodeID?) -> Bool {
        guard let dragged, let source = document.node(with: dragged.id), source !== node else {
            return false
        }
        if node.isContainer {
            document.move(source, into: node, at: node.children.count, undoManager: undoManager)
        } else if let parent = node.parent, let index = node.indexInParent {
            document.move(source, into: parent, at: index + 1, undoManager: undoManager)
        } else {
            return false
        }
        return true
    }

    @ViewBuilder
    private var keyContent: some View {
        if node.parent == nil {
            Text(verbatim: "Root").fontWeight(.medium)
        } else if node.keyIsEditable {
            keyEditor
        } else if let index = node.indexInParent {
            Text(verbatim: "Item \(index)").foregroundStyle(.secondary)
        } else {
            Text(verbatim: node.key)
        }
    }

    @ViewBuilder
    private var keyEditor: some View {
        if let definition {
            CompletingTextField(
                value: node.key,
                completions: { partial in keyCompletions(matching: partial, from: definition) },
                onCommit: { newKey in document.setKey(newKey, on: node, undoManager: undoManager) }
            )
            .help(definition.description(for: node.key) ?? "")
        } else {
            EditableTextField(node: node, value: node.key) { newKey in
                document.setKey(newKey, on: node, undoManager: undoManager)
            }
        }
    }

    private func keyCompletions(matching partial: String, from definition: StructureDefinition) -> [String] {
        let used = Set((node.parent?.children ?? []).filter { $0 !== node }.map(\.key))
        let prefix = partial.lowercased()
        return definition.keyNames
            .filter { !used.contains($0) && (prefix.isEmpty || $0.lowercased().hasPrefix(prefix)) }
            .sorted()
    }
}

/// Class column: an inline popup that retypes the node in place.
struct ClassCell: View {
    let document: PlistDocument
    let node: PlistNode
    let undoManager: UndoManager?

    var body: some View {
        Menu {
            ForEach(PlistType.menuOrder) { type in
                Button {
                    document.changeType(of: node, to: type, undoManager: undoManager)
                } label: {
                    Text(verbatim: type.displayName)
                }
            }
        } label: {
            Text(verbatim: node.plistType.displayName)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

/// Value column: a type-appropriate editor or a container summary.
struct ValueCell: View {
    let document: PlistDocument
    let node: PlistNode
    let undoManager: UndoManager?

    var body: some View {
        switch node.kind {
        case .dictionary(let items):
            Text(verbatim: Self.summary(items.count, singular: "key/value pair", plural: "key/value pairs"))
                .foregroundStyle(.secondary)
        case .array(let items):
            Text(verbatim: Self.summary(items.count, singular: "item", plural: "items"))
                .foregroundStyle(.secondary)
        case .boolean(let value):
            booleanEditor(value)
        case .date:
            EditableTextField(node: node, value: PlistValueText.editingString(for: node), isMonospaced: true) { text in
                document.commitValueText(text, on: node, undoManager: undoManager)
            }
        case .data, .integer, .real:
            formattedEditor
        case .string:
            EditableTextField(node: node, value: PlistValueText.editingString(for: node)) { text in
                document.commitValueText(text, on: node, undoManager: undoManager)
            }
        }
    }

    /// Value editor for Number / Data, honoring any active "View As" formatter.
    @ViewBuilder
    private var formattedEditor: some View {
        let formatter = document.viewAs[node.id] ?? ValueFormatter.defaultFormatter(for: node.plistType)
        let text = ValueFormatting.string(for: node, formatter: formatter)
        if formatter?.isEditable ?? true {
            EditableTextField(node: node, value: text, isMonospaced: node.plistType == .data) { newText in
                document.setKind(
                    ValueFormatting.kind(from: newText, formatter: formatter, node: node),
                    on: node,
                    undoManager: undoManager
                )
            }
        } else {
            Text(verbatim: text).foregroundStyle(.secondary)
        }
    }

    private func booleanEditor(_ value: Bool) -> some View {
        Menu {
            Button { setBoolean(true) } label: { Text(verbatim: "YES") }
            Button { setBoolean(false) } label: { Text(verbatim: "NO") }
        } label: {
            Text(verbatim: value ? "YES" : "NO")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func setBoolean(_ value: Bool) {
        document.setKind(.boolean(value), on: node, undoManager: undoManager)
    }

    /// Container summaries use English ("N items") as editor content.
    static func summary(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}
