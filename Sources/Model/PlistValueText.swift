import Foundation

/// Converts leaf node values to and from the editable text shown in the Value
/// column. Containers are summarized separately by the outline cell.
enum PlistValueText {

    // Formatters are only ever used on the main thread and are thread-safe for
    // formatting; marked unsafe to satisfy strict-concurrency static checks.
    nonisolated(unsafe) static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 15
        return formatter
    }()

    /// The string presented in an editable Value field for a leaf node.
    static func editingString(for node: PlistNode) -> String {
        switch node.kind {
        case .string(let value): return value
        case .integer(let value): return String(value)
        case .real(let value): return numberFormatter.string(from: value as NSNumber) ?? String(value)
        case .boolean(let value): return value ? "YES" : "NO"
        case .date(let value): return dateFormatter.string(from: value)
        case .data(let value): return hexString(from: value)
        case .array, .dictionary: return ""
        }
    }

    /// Parses edited text back into a node `Kind`, preserving the node's current
    /// type. Invalid input falls back to the node's existing value.
    static func kind(from text: String, preservingTypeOf node: PlistNode) -> PlistNode.Kind {
        switch node.kind {
        case .string:
            return .string(text)

        case .integer, .real:
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if !trimmed.contains(".") && !trimmed.lowercased().contains("e"),
               let intValue = Int64(trimmed) {
                return .integer(intValue)
            }
            if let doubleValue = Double(trimmed) {
                return .real(doubleValue)
            }
            return node.kind

        case .boolean:
            let lowered = text.trimmingCharacters(in: .whitespaces).lowercased()
            if ["yes", "true", "1"].contains(lowered) { return .boolean(true) }
            if ["no", "false", "0"].contains(lowered) { return .boolean(false) }
            return node.kind

        case .date:
            if let date = dateFormatter.date(from: text) { return .date(date) }
            return node.kind

        case .data:
            if let data = data(fromHex: text) { return .data(data) }
            return node.kind

        case .array, .dictionary:
            return node.kind
        }
    }

    // MARK: Hex helpers

    static func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    static func data(fromHex text: String) -> Data? {
        let cleaned = text.filter(\.isHexDigit)
        guard cleaned.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        return Data(bytes)
    }
}
