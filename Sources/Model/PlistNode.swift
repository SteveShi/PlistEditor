import Foundation
import Observation

/// A single node in the property-list tree. The node is the live, observable
/// source of truth that both the outline editor and the source-text renderer
/// read from. Container nodes (array / dictionary) own their children; leaf
/// nodes carry a scalar value.
// The tree is built off the main thread during file reads, then used only on
// the main thread thereafter (a one-time handoff), so unchecked Sendable is safe.
@Observable
final class PlistNode: Identifiable, @unchecked Sendable {
    /// The dictionary key for this node. Empty for the root and for array
    /// elements (whose displayed key is their positional index).
    var key: String
    var kind: Kind
    @ObservationIgnored weak var parent: PlistNode?

    let id = UUID()

    enum Kind {
        case string(String)
        case integer(Int64)
        case real(Double)
        case boolean(Bool)
        case date(Date)
        case data(Data)
        case array([PlistNode])
        case dictionary([PlistNode])
    }

    init(key: String = "", kind: Kind, parent: PlistNode? = nil) {
        self.key = key
        self.kind = kind
        self.parent = parent
    }

    // MARK: Derived properties

    var plistType: PlistType {
        switch kind {
        case .string: return .string
        case .integer, .real: return .number
        case .boolean: return .boolean
        case .date: return .date
        case .data: return .data
        case .array: return .array
        case .dictionary: return .dictionary
        }
    }

    var isContainer: Bool { plistType.isContainer }

    var children: [PlistNode] {
        switch kind {
        case .array(let items): return items
        case .dictionary(let items): return items
        default: return []
        }
    }

    var hasChildren: Bool {
        switch kind {
        case .array(let items): return !items.isEmpty
        case .dictionary(let items): return !items.isEmpty
        default: return false
        }
    }

    /// True when this node is a direct child of a dictionary, meaning its key is
    /// user-editable.
    var keyIsEditable: Bool {
        parent?.plistType == .dictionary
    }

    var indexInParent: Int? {
        guard let parent else { return nil }
        return parent.children.firstIndex { $0 === self }
    }

    // MARK: Child mutation

    /// Replaces the children of a container node, re-parenting each child.
    func setChildren(_ nodes: [PlistNode]) {
        for node in nodes { node.parent = self }
        switch kind {
        case .array: kind = .array(nodes)
        case .dictionary: kind = .dictionary(nodes)
        default: break
        }
    }

    func deepCopy() -> PlistNode {
        let copy: PlistNode
        switch kind {
        case .array(let items):
            copy = PlistNode(key: key, kind: .array([]))
            copy.setChildren(items.map { $0.deepCopy() })
        case .dictionary(let items):
            copy = PlistNode(key: key, kind: .dictionary([]))
            copy.setChildren(items.map { $0.deepCopy() })
        default:
            copy = PlistNode(key: key, kind: kind)
        }
        return copy
    }
}
