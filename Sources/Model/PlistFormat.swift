import Foundation

/// The on-disk serialization format of a document, chosen via the Format popup.
/// `openStep` is read-only (Foundation can parse old-style ASCII plists but
/// cannot write them); it is not offered for new documents in this version.
enum PlistFormat: String, CaseIterable, Identifiable, Sendable {
    case xml
    case binary
    case json
    case openStep

    var id: String { rawValue }

    /// Technical format name shown in the Format popup; kept in English as
    /// editor content rather than localized UI chrome.
    var displayName: String {
        switch self {
        case .xml: return "XML"
        case .binary: return "Binary"
        case .json: return "JSON"
        case .openStep: return "OpenStep"
        }
    }

    /// Formats the user may switch a document to. OpenStep is intentionally
    /// excluded because it cannot be written back.
    static var selectable: [PlistFormat] { [.xml, .binary, .json] }

    var canWrite: Bool { self != .openStep }

    /// The textual format used for the source pane. Binary plists have no
    /// textual form, so they are shown as XML text (the format the Format popup
    /// would round-trip through).
    var textRendering: TextRendering {
        switch self {
        case .xml, .binary: return .xml
        case .json: return .json
        case .openStep: return .openStep
        }
    }

    enum TextRendering { case xml, json, openStep }
}
