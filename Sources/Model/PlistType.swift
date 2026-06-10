import Foundation

/// The user-facing "Class" of a property-list node, mirroring the seven basic
/// property-list types. Integer and floating-point values are both presented as
/// `.number`, exactly as PlistEdit Pro does — the integer/real distinction is a
/// property of the stored value, not a separately selectable class.
enum PlistType: String, CaseIterable, Identifiable, Sendable {
    case dictionary
    case array
    case boolean
    case data
    case date
    case number
    case string

    var id: String { rawValue }

    /// The Class name shown in the editor. These are technical property-list
    /// type names and stay in English (matching Xcode / PlistEdit Pro); they are
    /// editor content, not localizable UI chrome.
    var displayName: String {
        switch self {
        case .dictionary: return "Dictionary"
        case .array: return "Array"
        case .boolean: return "Boolean"
        case .data: return "Data"
        case .date: return "Date"
        case .number: return "Number"
        case .string: return "String"
        }
    }

    var isContainer: Bool {
        self == .dictionary || self == .array
    }

    /// The order the types appear in the Class popup, matching PlistEdit Pro.
    static var menuOrder: [PlistType] {
        [.array, .dictionary, .boolean, .data, .date, .number, .string]
    }
}
