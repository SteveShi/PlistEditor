import Foundation

/// Renders the node tree into the text shown in the source pane. Binary and
/// OpenStep documents are rendered as XML text, since neither has an editable
/// textual form of its own.
enum PlistTextRenderer {
    static func text(from root: PlistNode, format: PlistFormat) throws -> String {
        switch format.textRendering {
        case .xml, .openStep:
            let data = try PlistSerializer.data(from: root, format: .xml)
            return String(decoding: data, as: UTF8.self)
        case .json:
            let data = try PlistSerializer.data(from: root, format: .json, jsonIndented: AppSettings.storedJSONDisplayIndented)
            return String(decoding: data, as: UTF8.self)
        }
    }
}
