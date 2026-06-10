import SwiftUI

/// The editor window: a vertical split of the outline over the source pane,
/// with the structural-edit toolbar and Format popup.
struct ContentView: View {
    @ObservedObject var document: PlistDocument
    var fileURL: URL?
    @State private var selection = Set<PlistNode.ID>()
    @State private var expanded = Set<PlistNode.ID>()
    @Environment(\.undoManager) private var undoManager

    @State private var findVisible = false
    @State private var findQuery = ""
    @State private var findReplacement = ""
    @State private var findMatches: [FindMatch] = []
    @State private var findIndex = -1

    // File-change monitoring
    @State private var fileWatcher: FileWatcher?
    @State private var showRevertAlert = false
    /// Snapshot of the on-disk data at last load/save so we can detect real changes.
    @State private var lastKnownData: Data?

    // View by subkey
    @State private var viewBySubkey: String? = nil
    @State private var showSubkeyPopover = false
    @State private var subkeyInput = ""

    var body: some View {
        VStack(spacing: 0) {
            if findVisible {
                FindBar(
                    query: $findQuery,
                    replacement: $findReplacement,
                    matchCount: findMatches.count,
                    currentIndex: findIndex,
                    onNext: nextMatch,
                    onPrevious: previousMatch,
                    onReplace: replaceCurrent,
                    onReplaceAll: replaceAll,
                    onClose: closeFind
                )
                Divider()
            }
            VSplitView {
                PlistOutlineView(document: document, selection: $selection, expanded: $expanded, definition: activeDefinition, viewBySubkey: viewBySubkey)
                    .frame(minHeight: 220)
                SourcePane(document: document)
                    .frame(minHeight: 140)
            }
        }
        .frame(minWidth: 680, minHeight: 480)
        .toolbar { toolbarContent }
        .focusedValue(\.editorActions, editorActions)
        .onAppear {
            applyInitialExpansion()
            startFileWatcher()
        }
        .onDisappear { fileWatcher?.stop() }
        .onChange(of: findQuery) { recomputeMatches() }
        .alert("revert.alert.title", isPresented: $showRevertAlert) {
            Button("revert.alert.reload") { revertDocument() }
            Button("revert.alert.keep", role: .cancel) {
                // Update snapshot so we don't keep alerting for the same change.
                if let fileURL { lastKnownData = try? Data(contentsOf: fileURL) }
            }
        } message: {
            Text("revert.alert.message")
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: addSibling) {
                Label("toolbar.addSibling", systemImage: "plus.square.on.square")
            }
            .help("toolbar.addSibling")

            Button(action: addChild) {
                Label("toolbar.addChild", systemImage: "plus.square")
            }
            .help("toolbar.addChild")
            .disabled(!targetCanHaveChild)

            Button(action: duplicate) {
                Label("toolbar.duplicate", systemImage: "doc.on.doc")
            }
            .help("toolbar.duplicate")
            .disabled(!canEditSelection)

            Button(action: deleteSelection) {
                Label("toolbar.delete", systemImage: "trash")
            }
            .help("toolbar.delete")
            .disabled(!canDeleteSelection)

            Button(action: toggleFind) {
                Label("toolbar.find", systemImage: "magnifyingglass")
            }
            .help("toolbar.find")
            .keyboardShortcut("f", modifiers: .command)
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                if let node = viewAsNode {
                    let current = document.viewAs[node.id] ?? ValueFormatter.defaultFormatter(for: node.plistType)
                    ForEach(ValueFormatter.formatters(for: node.plistType)) { formatter in
                        Button {
                            applyViewAs(formatter, to: node)
                        } label: {
                            if formatter == current {
                                Label(formatter.displayName, systemImage: "checkmark")
                            } else {
                                Text(verbatim: formatter.displayName)
                            }
                        }
                    }
                }
            } label: {
                Text("toolbar.viewAs")
            }
            .disabled(viewAsNode == nil)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                subkeyInput = viewBySubkey ?? ""
                showSubkeyPopover = true
            } label: {
                Label("toolbar.viewBySubkey", systemImage: "arrow.up.and.down.text.horizontal")
            }
            .help("toolbar.viewBySubkey")
            .popover(isPresented: $showSubkeyPopover, arrowEdge: .bottom) {
                VStack(spacing: 12) {
                    TextField("viewBySubkey.placeholder", text: $subkeyInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .onSubmit {
                            viewBySubkey = subkeyInput.isEmpty ? nil : subkeyInput
                            showSubkeyPopover = false
                        }
                    
                    HStack {
                        Button("viewBySubkey.clear") {
                            viewBySubkey = nil
                            subkeyInput = ""
                            showSubkeyPopover = false
                        }
                        .disabled(viewBySubkey == nil)
                        
                        Spacer()
                        
                        Button("action.ok") {
                            viewBySubkey = subkeyInput.isEmpty ? nil : subkeyInput
                            showSubkeyPopover = false
                        }
                    }
                }
                .padding()
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Picker(selection: formatBinding) {
                ForEach(PlistFormat.selectable) { format in
                    Text(verbatim: format.displayName).tag(format)
                }
            } label: {
                Text("toolbar.format")
            }
            .pickerStyle(.menu)
        }
    }

    /// The structure definition matching this document's file name, if any.
    private var activeDefinition: StructureDefinition? {
        StructureDefinitionStore.shared.definition(forFileNamed: fileURL?.lastPathComponent)
    }

    /// The single selected Number/Data node eligible for a "View As" formatter.
    private var viewAsNode: PlistNode? {
        guard selectedNodes.count == 1, let node = selectedNodes.first,
              !ValueFormatter.formatters(for: node.plistType).isEmpty else { return nil }
        return node
    }

    private var formatBinding: Binding<PlistFormat> {
        Binding(
            get: { document.format },
            set: { document.setFormat($0, undoManager: undoManager) }
        )
    }

    // MARK: Selection

    /// All selected nodes in tree (document) order.
    private var selectedNodes: [PlistNode] {
        guard !selection.isEmpty else { return [] }
        var result: [PlistNode] = []
        func visit(_ node: PlistNode) {
            if selection.contains(node.id) { result.append(node) }
            for child in node.children { visit(child) }
        }
        visit(document.root)
        return result
    }

    /// The node a new sibling/child is added relative to (first selection or root).
    private var target: PlistNode { selectedNodes.first ?? document.root }

    private var targetCanHaveChild: Bool { target.isContainer }
    private var canEditSelection: Bool { selectedNodes.contains { $0.parent != nil } }
    private var canDeleteSelection: Bool { selectedNodes.contains { $0.parent != nil } }

    private var canPaste: Bool {
        guard let types = NSPasteboard.general.types else { return false }
        let customType = NSPasteboard.PasteboardType("com.steveshi.plisteditor.nodes")
        let plistType = NSPasteboard.PasteboardType("NSPropertyListPboardType")
        return types.contains(customType) || types.contains(plistType) || types.contains(.string)
    }

    private var canSortKeys: Bool {
        if selectedNodes.isEmpty {
            return document.root.plistType == .dictionary
        }
        return selectedNodes.contains { $0.plistType == .dictionary }
            || selectedNodes.contains { $0.parent?.plistType == .dictionary }
    }

    private var editorActions: EditorActions {
        EditorActions(
            addSibling: addSibling,
            addChild: addChild,
            duplicate: duplicate,
            delete: deleteSelection,
            copy: copySelection,
            cut: cutSelection,
            paste: pasteNodes,
            sortKeys: sortKeys,
            canEditSelection: canEditSelection,
            canAddChild: targetCanHaveChild,
            canDelete: canDeleteSelection,
            canPaste: canPaste,
            canSortKeys: canSortKeys
        )
    }

    // MARK: Actions

    private func addSibling() {
        let node = target
        let created: PlistNode?
        if node.parent == nil {
            created = document.addChild(to: node, undoManager: undoManager)
            expanded.insert(node.id)
        } else {
            created = document.addSibling(to: node, undoManager: undoManager)
            if let parent = node.parent { expanded.insert(parent.id) }
        }
        selectCreated(created)
    }

    private func addChild() {
        let node = target
        guard node.isContainer else { return }
        expanded.insert(node.id)
        selectCreated(document.addChild(to: node, undoManager: undoManager))
    }

    private func duplicate() {
        let nodes = selectedNodes.filter { $0.parent != nil }
        var created: Set<PlistNode.ID> = []
        for node in nodes {
            if let copy = document.duplicate(node, undoManager: undoManager) {
                created.insert(copy.id)
            }
        }
        if !created.isEmpty { selection = created }
    }

    private func deleteSelection() {
        // Delete only the top-most selected nodes so a selected subtree isn't
        // deleted twice; identity lookups keep indices correct between removals.
        let nodes = selectedNodes.filter { $0.parent != nil }
        let topLevel = nodes.filter { node in
            var ancestor = node.parent
            while let current = ancestor {
                if nodes.contains(where: { $0 === current }) { return false }
                ancestor = current.parent
            }
            return true
        }
        for node in topLevel {
            document.delete(node, undoManager: undoManager)
        }
        selection.removeAll()
    }

    private func copySelection() {
        let nodes = selectedNodes
        let topLevel = nodes.filter { node in
            var ancestor = node.parent
            while let current = ancestor {
                if nodes.contains(where: { $0 === current }) { return false }
                ancestor = current.parent
            }
            return true
        }
        guard !topLevel.isEmpty else { return }

        let wrappedList = topLevel.map { node -> [String: Any] in
            return [
                "key": node.key,
                "value": PlistSerializer.foundationObject(from: node)
            ]
        }

        let standardObject: Any
        if topLevel.count == 1 {
            standardObject = PlistSerializer.foundationObject(from: topLevel[0])
        } else {
            standardObject = topLevel.map { PlistSerializer.foundationObject(from: $0) }
        }

        let pb = NSPasteboard.general
        pb.clearContents()

        if let wrappedData = try? PropertyListSerialization.data(fromPropertyList: wrappedList, format: .xml, options: 0) {
            pb.setData(wrappedData, forType: NSPasteboard.PasteboardType("com.steveshi.plisteditor.nodes"))
        }

        if let standardData = try? PropertyListSerialization.data(fromPropertyList: standardObject, format: .xml, options: 0) {
            pb.setData(standardData, forType: NSPasteboard.PasteboardType("NSPropertyListPboardType"))
            if let str = String(data: standardData, encoding: .utf8) {
                pb.setString(str, forType: .string)
            }
        }
    }

    private func cutSelection() {
        copySelection()
        deleteSelection()
    }

    private func pasteNodes() {
        let targetNode = target
        let destParent: PlistNode
        let insertIndex: Int
        if targetNode.isContainer {
            destParent = targetNode
            insertIndex = targetNode.children.count
        } else if let parent = targetNode.parent {
            destParent = parent
            if let idx = parent.children.firstIndex(where: { $0 === targetNode }) {
                insertIndex = idx + 1
            } else {
                insertIndex = parent.children.count
            }
        } else {
            destParent = targetNode
            insertIndex = targetNode.children.count
        }

        let pb = NSPasteboard.general
        var newNodes: [PlistNode] = []

        if let data = pb.data(forType: NSPasteboard.PasteboardType("com.steveshi.plisteditor.nodes")),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]] {
            for dict in plist {
                if let key = dict["key"] as? String, let val = dict["value"] {
                    newNodes.append(PlistSerializer.makeNode(from: val, key: key))
                }
            }
        } else if let data = pb.data(forType: NSPasteboard.PasteboardType("NSPropertyListPboardType")),
                  let val = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
            if let dict = val as? [String: Any] {
                for (k, v) in dict.sorted(by: { AppSettings.compareKeys($0.key, $1.key) == .orderedAscending }) {
                    newNodes.append(PlistSerializer.makeNode(from: v, key: k))
                }
            } else if let array = val as? [Any] {
                for v in array {
                    newNodes.append(PlistSerializer.makeNode(from: v, key: ""))
                }
            } else {
                newNodes.append(PlistSerializer.makeNode(from: val, key: "Item"))
            }
        } else if let text = pb.string(forType: .string) {
            if let data = text.data(using: .utf8),
               let parsed = try? PlistSerializer.parse(data) {
                newNodes.append(parsed.root)
            } else {
                newNodes.append(PlistNode(key: "Item", kind: .string(text)))
            }
        }

        guard !newNodes.isEmpty else { return }

        let pasted = document.paste(newNodes, into: destParent, at: insertIndex, undoManager: undoManager)
        expanded.insert(destParent.id)
        if !pasted.isEmpty {
            selection = Set(pasted.map(\.id))
        }
    }

    private func sortKeys() {
        var targetDicts: [PlistNode] = []
        if selectedNodes.isEmpty {
            if document.root.plistType == .dictionary {
                targetDicts.append(document.root)
            }
        } else {
            for node in selectedNodes {
                if node.plistType == .dictionary {
                    if !targetDicts.contains(where: { $0 === node }) {
                        targetDicts.append(node)
                    }
                } else if let parent = node.parent, parent.plistType == .dictionary {
                    if !targetDicts.contains(where: { $0 === parent }) {
                        targetDicts.append(parent)
                    }
                }
            }
        }

        for dict in targetDicts {
            document.sortChildren(of: dict, undoManager: undoManager)
        }
    }

    private func selectCreated(_ node: PlistNode?) {
        guard let node else { return }
        selection = [node.id]
    }

    /// Expands the root (and optionally all descendants) when the window opens.
    private func applyInitialExpansion() {
        guard expanded.isEmpty else { return }
        expanded.insert(document.root.id)
        guard AppSettings.shared.expandOnOpen == .allChildren else { return }
        func visit(_ node: PlistNode) {
            if node.isContainer {
                expanded.insert(node.id)
                for child in node.children { visit(child) }
            }
        }
        visit(document.root)
    }

    // MARK: File Change Monitoring

    /// Starts watching `fileURL` for external modifications.
    private func startFileWatcher() {
        guard let fileURL else { return }
        lastKnownData = try? Data(contentsOf: fileURL)
        fileWatcher = FileWatcher(url: fileURL) { [fileURL] in
            handleExternalChange(at: fileURL)
        }
    }

    /// Called (on the main actor) when the watcher detects a file-system event.
    private func handleExternalChange(at url: URL) {
        guard let newData = try? Data(contentsOf: url) else { return }
        // Ignore events that didn't actually change the content (e.g. metadata touch).
        if newData == lastKnownData { return }

        if AppSettings.shared.askToRevert {
            showRevertAlert = true
        } else {
            revertDocument()
        }
    }

    /// Reloads the document from disk, replacing the current root and source text.
    private func revertDocument() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        guard let parsed = try? PlistSerializer.parse(data) else { return }
        let resolvedFormat = parsed.format.canWrite ? parsed.format : .xml
        document.setRoot(parsed.root, format: resolvedFormat, undoManager: undoManager)
        lastKnownData = data
    }

    /// Applies a "View As" formatter, extending it to all nodes that share the
    /// key when "Remember formatter types by key" is enabled.
    private func applyViewAs(_ formatter: ValueFormatter, to node: PlistNode) {
        document.viewAs[node.id] = formatter
        guard AppSettings.shared.rememberFormatterByKey, !node.key.isEmpty else { return }
        func visit(_ candidate: PlistNode) {
            if candidate.key == node.key, candidate.plistType == node.plistType {
                document.viewAs[candidate.id] = formatter
            }
            for child in candidate.children { visit(child) }
        }
        visit(document.root)
    }

    // MARK: Find / Replace

    private func toggleFind() {
        findVisible.toggle()
        if findVisible { recomputeMatches() } else { clearFind() }
    }

    private func closeFind() {
        findVisible = false
        clearFind()
    }

    private func clearFind() {
        findMatches = []
        findIndex = -1
    }

    private func recomputeMatches() {
        guard findVisible, !findQuery.isEmpty else { clearFind(); return }
        let needle = findQuery.lowercased()
        var result: [FindMatch] = []
        func visit(_ node: PlistNode) {
            if node.keyIsEditable, node.key.lowercased().contains(needle) {
                result.append(FindMatch(nodeID: node.id, field: .key))
            }
            if !node.isContainer, PlistValueText.editingString(for: node).lowercased().contains(needle) {
                result.append(FindMatch(nodeID: node.id, field: .value))
            }
            for child in node.children { visit(child) }
        }
        visit(document.root)
        findMatches = result
        findIndex = result.isEmpty ? -1 : min(max(findIndex, 0), result.count - 1)
        focusCurrentMatch()
    }

    private func focusCurrentMatch() {
        guard findIndex >= 0, findIndex < findMatches.count,
              let node = document.node(with: findMatches[findIndex].nodeID) else { return }
        var ancestor = node.parent
        while let current = ancestor {
            expanded.insert(current.id)
            ancestor = current.parent
        }
        selection = [node.id]
    }

    private func nextMatch() {
        guard !findMatches.isEmpty else { return }
        findIndex = (findIndex + 1) % findMatches.count
        focusCurrentMatch()
    }

    private func previousMatch() {
        guard !findMatches.isEmpty else { return }
        findIndex = (findIndex - 1 + findMatches.count) % findMatches.count
        focusCurrentMatch()
    }

    private func replaceCurrent() {
        guard findIndex >= 0, findIndex < findMatches.count else { return }
        apply(match: findMatches[findIndex])
        recomputeMatches()
    }

    private func replaceAll() {
        for match in findMatches { apply(match: match) }
        recomputeMatches()
    }

    private func apply(match: FindMatch) {
        guard let node = document.node(with: match.nodeID) else { return }
        switch match.field {
        case .key:
            let newKey = node.key.replacingOccurrences(
                of: findQuery, with: findReplacement, options: [.caseInsensitive]
            )
            document.setKey(newKey, on: node, undoManager: undoManager)
        case .value:
            let text = PlistValueText.editingString(for: node)
            let newText = text.replacingOccurrences(
                of: findQuery, with: findReplacement, options: [.caseInsensitive]
            )
            document.commitValueText(newText, on: node, undoManager: undoManager)
        }
    }
}
