import Foundation

/// Errors surfaced while reading, writing, or syncing property-list content.
enum PlistError: LocalizedError {
    case unparseable(message: String, line: Int?)
    case notValidJSON
    case cannotWriteOpenStep

    var errorDescription: String? {
        switch self {
        case .unparseable(let message, let line):
            if let line {
                return String(localized: "error.parse.withLine \(line) \(message)")
            }
            return String(localized: "error.parse \(message)")
        case .notValidJSON:
            return String(localized: "error.json.invalid")
        case .cannotWriteOpenStep:
            return String(localized: "error.openStep.write")
        }
    }
}
