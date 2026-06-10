import SwiftUI

/// The top pane: a three-column outline of the property list. Arbitrary depth
/// is supported by flattening the currently visible rows and drawing disclosure
/// chevrons in the Key cell, which sidesteps SwiftUI `Table`'s limited support
/// for recursive hierarchies.
struct PlistOutlineView: View {
    @ObservedObject var document: PlistDocument
    @Binding var selection: Set<PlistNode.ID>
    @Binding var expanded: Set<PlistNode.ID>
    let definition: StructureDefinition?
    let viewBySubkey: String?
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.undoManager) private var undoManager

    private var visibleRows: [PlistNode] {
        var rows: [PlistNode] = []
        func visit(_ node: PlistNode) {
            rows.append(node)
            if node.isContainer, expanded.contains(node.id) {
                let children: [PlistNode]
                if let subkey = viewBySubkey, !subkey.isEmpty {
                    children = node.children.sorted { c1, c2 in
                        let val1 = subkeyValue(for: c1, subkey: subkey)
                        let val2 = subkeyValue(for: c2, subkey: subkey)
                        return val1.localizedStandardCompare(val2) == .orderedAscending
                    }
                } else {
                    children = node.children
                }
                for child in children { visit(child) }
            }
        }
        visit(document.root)
        return rows
    }

    private func subkeyValue(for node: PlistNode, subkey: String) -> String {
        if node.isContainer {
            if let match = node.children.first(where: { $0.key == subkey }) {
                if match.isContainer {
                    return ""
                } else {
                    return ValueFormatting.string(for: match, formatter: document.viewAs[match.id])
                }
            }
        }
        return ""
    }

    var body: some View {
        Table(of: PlistNode.self, selection: $selection) {
            TableColumn(Text("column.key")) { node in
                KeyCell(
                    document: document,
                    node: node,
                    undoManager: undoManager,
                    isExpanded: expanded.contains(node.id),
                    toggle: { toggle(node) },
                    definition: definition
                )
            }
            .width(min: 200, ideal: 320)

            TableColumn(Text("column.class")) { node in
                ClassCell(document: document, node: node, undoManager: undoManager)
            }
            .width(min: 110, ideal: 150)

            TableColumn(Text("column.value")) { node in
                ValueCell(document: document, node: node, undoManager: undoManager)
            }
            .width(min: 160, ideal: 360)
        } rows: {
            ForEach(visibleRows) { node in
                TableRow(node)
            }
        }
        .font(settings.outlineFont.swiftUIFont)
        .environment(\.selectNextRow) { [visibleRows] currentID in
            MainActor.assumeIsolated {
                guard let index = visibleRows.firstIndex(where: { $0.id == currentID }),
                      index + 1 < visibleRows.count else { return }
                selection = [visibleRows[index + 1].id]
            }
        }
    }

    private func toggle(_ node: PlistNode) {
        if expanded.contains(node.id) {
            expanded.remove(node.id)
        } else {
            expanded.insert(node.id)
        }
    }
}
