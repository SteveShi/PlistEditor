import AppKit

extension NSDocument {
    @objc func scriptingFormat() -> String {
        if let plistDoc = findPlistDocument(in: self) {
            return plistDoc.format.rawValue
        }
        return "xml"
    }

    @objc func setScriptingFormat(_ newValue: String) {
        let formatString = newValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let plistDoc = findPlistDocument(in: self) {
            DispatchQueue.main.async {
                if let format = PlistFormat(rawValue: formatString) {
                    plistDoc.setFormat(format, undoManager: self.undoManager)
                }
            }
        }
    }

    private func findPlistDocument(in doc: NSDocument) -> PlistDocument? {
        var queue: [Any] = [doc]
        var visited = 0
        while visited < queue.count && visited < 100 {
            let item = queue[visited]
            visited += 1
            
            if let plistDoc = item as? PlistDocument {
                return plistDoc
            }
            
            let mirror = Mirror(reflecting: item)
            for child in mirror.children {
                queue.append(child.value)
            }
        }
        return nil
    }
}
