import Foundation

/// Drag-and-drop move / re-parent support. A move is a single undoable unit that
/// restores the original parent, index, and key on undo.
@MainActor
extension PlistDocument {

    /// Moves `node` into `newParent` at `index`. No-ops if it would create a
    /// cycle (moving a node into itself or one of its descendants).
    func move(_ node: PlistNode, into newParent: PlistNode, at index: Int, undoManager: UndoManager?) {
        guard let oldParent = node.parent, let oldIndex = node.indexInParent else { return }
        guard newParent !== node, !isDescendant(newParent, of: node) else { return }

        let oldKey = node.key
        let newKey: String
        if newParent.plistType == .dictionary {
            let collides = newParent.children.contains { $0 !== node && $0.key == node.key }
            newKey = (node.key.isEmpty || collides)
                ? uniqueKey(basedOn: node.key.isEmpty ? Self.newItemKeyBase : node.key, in: newParent)
                : node.key
        } else {
            newKey = ""
        }

        applyMove(
            node, from: oldParent, fromIndex: oldIndex,
            to: newParent, at: index,
            newKey: newKey, oldKey: oldKey,
            undoManager: undoManager
        )
    }

    private func applyMove(
        _ node: PlistNode,
        from oldParent: PlistNode, fromIndex: Int,
        to newParent: PlistNode, at index: Int,
        newKey: String, oldKey: String,
        undoManager: UndoManager?
    ) {
        var oldChildren = oldParent.children
        guard oldChildren.indices.contains(fromIndex) else { return }
        oldChildren.remove(at: fromIndex)
        oldParent.setChildren(oldChildren)

        var insertIndex = index
        if oldParent === newParent, fromIndex < insertIndex { insertIndex -= 1 }

        node.key = newKey
        var newChildren = newParent.children
        insertIndex = min(max(insertIndex, 0), newChildren.count)
        newChildren.insert(node, at: insertIndex)
        newParent.setChildren(newChildren)

        let landedIndex = insertIndex
        undoManager?.registerUndo(withTarget: self) { document in
            MainActor.assumeIsolated {
                document.applyMove(
                    node, from: newParent, fromIndex: landedIndex,
                    to: oldParent, at: fromIndex,
                    newKey: oldKey, oldKey: newKey,
                    undoManager: undoManager
                )
            }
        }
        didMutateOutline()
    }

    /// Finds a node anywhere in the tree by identity.
    func node(with id: PlistNode.ID) -> PlistNode? {
        func search(_ node: PlistNode) -> PlistNode? {
            if node.id == id { return node }
            for child in node.children {
                if let match = search(child) { return match }
            }
            return nil
        }
        return search(root)
    }

    /// True if `node` is `ancestor` or appears anywhere below it.
    func isDescendant(_ node: PlistNode, of ancestor: PlistNode) -> Bool {
        var current: PlistNode? = node
        while let candidate = current {
            if candidate === ancestor { return true }
            current = candidate.parent
        }
        return false
    }
}
