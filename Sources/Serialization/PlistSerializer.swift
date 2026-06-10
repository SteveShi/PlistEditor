import Foundation

/// Bridges between the live `PlistNode` tree and Foundation's serialization
/// stack. The resulting `Data` is the only value handed to the document's
/// background write; reading runs on the document-controller's open queue.
enum PlistSerializer {

    // MARK: Reading

    /// Parses arbitrary file data, detecting the format. Empty data yields an
    /// empty root dictionary in XML format (a fresh "Untitled" document).
    static func parse(_ data: Data) throws -> (root: PlistNode, format: PlistFormat) {
        guard !data.isEmpty else {
            return (PlistNode(kind: .dictionary([])), .xml)
        }

        var cfFormat = PropertyListSerialization.PropertyListFormat.xml
        if let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: &cfFormat) {
            return (makeNode(from: object, key: ""), map(cfFormat))
        }

        if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            return (makeNode(from: object, key: ""), .json)
        }

        // Re-run XML parsing to capture a meaningful error message for the user.
        do {
            _ = try PropertyListSerialization.propertyList(from: data, options: [], format: &cfFormat)
        } catch {
            throw PlistError.unparseable(message: error.localizedDescription, line: lineNumber(in: error))
        }
        throw PlistError.unparseable(message: "", line: nil)
    }

    /// Parses source-pane text during a "Sync outline" operation.
    static func parseText(_ text: String) throws -> (root: PlistNode, format: PlistFormat) {
        try parse(Data(text.utf8))
    }

    // MARK: Writing

    static func data(from root: PlistNode, format: PlistFormat, jsonIndented: Bool = true) throws -> Data {
        let object = foundationObject(from: root)
        switch format {
        case .xml:
            return try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
        case .binary:
            return try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
        case .json:
            guard JSONSerialization.isValidJSONObject(object) else { throw PlistError.notValidJSON }
            var options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
            if jsonIndented { options.insert(.prettyPrinted) }
            return try JSONSerialization.data(withJSONObject: object, options: options)
        case .openStep:
            throw PlistError.cannotWriteOpenStep
        }
    }

    // MARK: Node tree -> Foundation

    static func foundationObject(from node: PlistNode) -> Any {
        switch node.kind {
        case .string(let value):
            return value as NSString
        case .integer(let value):
            return NSNumber(value: value)
        case .real(let value):
            return NSNumber(value: value)
        case .boolean(let value):
            return (value ? kCFBooleanTrue : kCFBooleanFalse) as Any
        case .date(let value):
            return value as NSDate
        case .data(let value):
            return value as NSData
        case .array(let items):
            return items.map { foundationObject(from: $0) }
        case .dictionary(let items):
            var dict = [String: Any](minimumCapacity: items.count)
            for item in items { dict[item.key] = foundationObject(from: item) }
            return dict
        }
    }

    // MARK: Foundation -> Node tree

    static func makeNode(from object: Any, key: String) -> PlistNode {
        switch object {
        case let dict as [String: Any]:
            let node = PlistNode(key: key, kind: .dictionary([]))
            // Dictionary keys serialize alphabetically; sort respecting user prefs.
            let children = dict.keys.sorted { AppSettings.compareKeys($0, $1) == .orderedAscending }
                .map { makeNode(from: dict[$0]!, key: $0) }
            node.setChildren(children)
            return node

        case let array as [Any]:
            let node = PlistNode(key: key, kind: .array([]))
            node.setChildren(array.map { makeNode(from: $0, key: "") })
            return node

        case let number as NSNumber:
            if isBoolean(number) {
                return PlistNode(key: key, kind: .boolean(number.boolValue))
            }
            if CFNumberIsFloatType(number as CFNumber) {
                return PlistNode(key: key, kind: .real(number.doubleValue))
            }
            return PlistNode(key: key, kind: .integer(number.int64Value))

        case let date as Date:
            return PlistNode(key: key, kind: .date(date))

        case let data as Data:
            return PlistNode(key: key, kind: .data(data))

        case let string as String:
            return PlistNode(key: key, kind: .string(string))

        case is NSNull:
            // JSON null has no plist equivalent; represent as an empty string.
            return PlistNode(key: key, kind: .string(""))

        default:
            return PlistNode(key: key, kind: .string(String(describing: object)))
        }
    }

    // MARK: Helpers

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func map(_ format: PropertyListSerialization.PropertyListFormat) -> PlistFormat {
        switch format {
        case .xml: return .xml
        case .binary: return .binary
        case .openStep: return .openStep
        @unknown default: return .xml
        }
    }

    /// Best-effort extraction of a line number from a Foundation parse error.
    private static func lineNumber(in error: Error) -> Int? {
        let description = (error as NSError).localizedDescription
        guard let range = description.range(of: #"line (\d+)"#, options: .regularExpression) else {
            return nil
        }
        let digits = description[range].filter(\.isNumber)
        return Int(digits)
    }
}
