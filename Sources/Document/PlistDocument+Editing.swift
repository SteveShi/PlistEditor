import Foundation

/// Undoable editing operations on the node tree. Every structural change
/// registers its inverse with the supplied `UndoManager`, which also marks the
/// document dirty.
@MainActor
extension PlistDocument {

    /// Default key used for new dictionary entries (matches Xcode/PlistEdit Pro).
    static let newItemKeyBase = "New item"

    // MARK: Adding

    @discardableResult
    func addChild(to parent: PlistNode, undoManager: UndoManager?) -> PlistNode? {
        guard parent.isContainer else { return nil }
        let node = makeNewNode(in: parent)
        insert(node, into: parent, at: parent.children.count, undoManager: undoManager)
        return node
    }

    @discardableResult
    func addSibling(to node: PlistNode, undoManager: UndoManager?) -> PlistNode? {
        guard let parent = node.parent, let index = node.indexInParent else {
            // No parent (root selected): fall back to adding a child.
            return addChild(to: node, undoManager: undoManager)
        }
        let newNode = makeNewNode(in: parent)
        insert(newNode, into: parent, at: index + 1, undoManager: undoManager)
        return newNode
    }

    @discardableResult
    func duplicate(_ node: PlistNode, undoManager: UndoManager?) -> PlistNode? {
        guard let parent = node.parent, let index = node.indexInParent else { return nil }
        let copy = node.deepCopy()
        if parent.plistType == .dictionary {
            copy.key = uniqueKey(basedOn: node.key, in: parent)
        }
        insert(copy, into: parent, at: index + 1, undoManager: undoManager)
        return copy
    }

    // MARK: Removing

    func delete(_ node: PlistNode, undoManager: UndoManager?) {
        guard let parent = node.parent, let index = node.indexInParent else { return }
        remove(at: index, from: parent, undoManager: undoManager)
    }

    // MARK: Core insert / remove (mutually inverse)

    func insert(_ node: PlistNode, into parent: PlistNode, at index: Int, undoManager: UndoManager?) {
        var children = parent.children
        let clamped = min(max(index, 0), children.count)
        children.insert(node, at: clamped)
        parent.setChildren(children)
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.remove(at: clamped, from: parent, undoManager: undoManager)
            }
        }
        didMutateOutline()
    }

    func remove(at index: Int, from parent: PlistNode, undoManager: UndoManager?) {
        var children = parent.children
        guard children.indices.contains(index) else { return }
        let removed = children.remove(at: index)
        parent.setChildren(children)
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.insert(removed, into: parent, at: index, undoManager: undoManager)
            }
        }
        didMutateOutline()
    }

    // MARK: Editing key / value / type

    func setKey(_ newKey: String, on node: PlistNode, undoManager: UndoManager?) {
        guard node.keyIsEditable, node.key != newKey else { return }
        let oldKey = node.key
        node.key = newKey
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.setKey(oldKey, on: node, undoManager: undoManager)
            }
        }
        didMutateOutline()
    }

    func setKind(_ newKind: PlistNode.Kind, on node: PlistNode, undoManager: UndoManager?) {
        let oldKind = node.kind
        node.setChildrenParentIfNeeded(for: newKind)
        node.kind = newKind
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.setKind(oldKind, on: node, undoManager: undoManager)
            }
        }
        didMutateOutline()
    }

    /// Commits an edited Value field, keeping the node's existing type.
    func commitValueText(_ text: String, on node: PlistNode, undoManager: UndoManager?) {
        setKind(PlistValueText.kind(from: text, preservingTypeOf: node), on: node, undoManager: undoManager)
    }

    /// Changes a node's Class, converting the existing value as best it can.
    func changeType(of node: PlistNode, to type: PlistType, undoManager: UndoManager?) {
        guard node.plistType != type else { return }
        setKind(convertedKind(of: node, to: type), on: node, undoManager: undoManager)
    }

    // MARK: Helpers

    private func makeNewNode(in parent: PlistNode) -> PlistNode {
        let key = parent.plistType == .dictionary
            ? uniqueKey(basedOn: Self.newItemKeyBase, in: parent)
            : ""
        return PlistNode(key: key, kind: Self.defaultKind(for: AppSettings.shared.defaultClass))
    }

    /// An empty value of the given type, used for newly created nodes.
    static func defaultKind(for type: PlistType) -> PlistNode.Kind {
        switch type {
        case .string: return .string("")
        case .number: return .integer(0)
        case .boolean: return .boolean(false)
        case .date: return .date(Date())
        case .data: return .data(Data())
        case .array: return .array([])
        case .dictionary: return .dictionary([])
        }
    }

    func uniqueKey(basedOn base: String, in parent: PlistNode) -> String {
        let existing = Set(parent.children.map(\.key))
        let trimmedBase = base.isEmpty ? Self.newItemKeyBase : base
        if !existing.contains(trimmedBase) { return trimmedBase }
        var index = 2
        while existing.contains("\(trimmedBase) \(index)") { index += 1 }
        return "\(trimmedBase) \(index)"
    }

    /// Best-effort conversion of a node's value to a new type.
    private func convertedKind(of node: PlistNode, to type: PlistType) -> PlistNode.Kind {
        let text = PlistValueText.editingString(for: node)
        switch type {
        case .string:
            return .string(node.isContainer ? "" : text)
        case .number:
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if !trimmed.contains("."), let value = Int64(trimmed) { return .integer(value) }
            if let value = Double(trimmed) { return .real(value) }
            return .integer(0)
        case .boolean:
            return .boolean(["yes", "true", "1"].contains(text.lowercased()))
        case .date:
            return .date(PlistValueText.dateFormatter.date(from: text) ?? Date())
        case .data:
            return .data(PlistValueText.data(fromHex: text) ?? Data(text.utf8))
        case .array:
            if case .dictionary(let items) = node.kind { return .array(items) }
            return .array([])
        case .dictionary:
            if case .array(let items) = node.kind {
                for (index, item) in items.enumerated() where item.key.isEmpty {
                    item.key = "\(Self.newItemKeyBase) \(index)"
                }
                return .dictionary(items)
            }
            return .dictionary([])
        }
    }

    // MARK: Sorting and Clipboard operations

    func sortChildren(of node: PlistNode, undoManager: UndoManager?) {
        guard node.isContainer else { return }
        let originalChildren = node.children
        let sortedChildren = originalChildren.sorted {
            AppSettings.compareKeys($0.key, $1.key) == .orderedAscending
        }
        let changed = !sortedChildren.elementsEqual(originalChildren, by: { $0 === $1 })
        guard changed else { return }

        node.setChildren(sortedChildren)
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                node.setChildren(originalChildren)
                document.didMutateOutline()
            }
        }
        didMutateOutline()
    }

    @discardableResult
    func paste(_ nodes: [PlistNode], into parent: PlistNode, at index: Int, undoManager: UndoManager?) -> [PlistNode] {
        guard parent.isContainer else { return [] }
        var pasted: [PlistNode] = []
        var currentIndex = index
        for node in nodes {
            let copy = node.deepCopy()
            if parent.plistType == .dictionary {
                copy.key = uniqueKey(basedOn: node.key, in: parent)
            } else {
                copy.key = ""
            }
            insert(copy, into: parent, at: currentIndex, undoManager: undoManager)
            pasted.append(copy)
            currentIndex += 1
        }
        return pasted
    }
}

private extension PlistNode {
    /// Re-parents the children carried by an incoming container `Kind` so the
    /// tree stays consistent after a type change or undo.
    func setChildrenParentIfNeeded(for kind: Kind) {
        switch kind {
        case .array(let items), .dictionary(let items):
            for item in items { item.parent = self }
        default:
            break
        }
    }
}
