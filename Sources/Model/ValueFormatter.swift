import Foundation

/// "View As" presentations that reinterpret a Number or Data value for display
/// and (where reversible) editing. The underlying stored value keeps its type;
/// only its textual representation changes.
enum ValueFormatter: String, CaseIterable, Identifiable, Sendable {
    // Number
    case decimal
    case hex
    case osType
    case storageSize
    case hms
    // Data
    case dataHex
    case utf8
    case ascii
    case base64
    case uint16LE
    case uint16BE
    case uint32LE
    case uint32BE
    case float32LE
    case float32BE

    var id: String { rawValue }

    /// Technical formatter name, shown in the View As menu (kept in English).
    var displayName: String {
        switch self {
        case .decimal: return "Decimal"
        case .hex: return "Hex"
        case .osType: return "OSType"
        case .storageSize: return "Storage Size"
        case .hms: return "HH:MM:SS"
        case .dataHex: return "Hex"
        case .utf8: return "UTF-8 String"
        case .ascii: return "ASCII String"
        case .base64: return "Base64"
        case .uint16LE: return "UInt16 (Little Endian)"
        case .uint16BE: return "UInt16 (Big Endian)"
        case .uint32LE: return "UInt32 (Little Endian)"
        case .uint32BE: return "UInt32 (Big Endian)"
        case .float32LE: return "Float32 (Little Endian)"
        case .float32BE: return "Float32 (Big Endian)"
        }
    }

    /// Storage Size, HH:MM:SS and byte-order variants are lossy or read-only, so they are display-only.
    var isEditable: Bool {
        switch self {
        case .storageSize, .hms: return false
        case .uint16LE, .uint16BE, .uint32LE, .uint32BE, .float32LE, .float32BE: return false
        default: return true
        }
    }

    static func formatters(for type: PlistType) -> [ValueFormatter] {
        switch type {
        case .number: return [.decimal, .hex, .osType, .storageSize, .hms]
        case .data: return [.dataHex, .utf8, .ascii, .base64, .uint16LE, .uint16BE, .uint32LE, .uint32BE, .float32LE, .float32BE]
        default: return []
        }
    }

    static func defaultFormatter(for type: PlistType) -> ValueFormatter? {
        switch type {
        case .number: return .decimal
        case .data: return .dataHex
        default: return nil
        }
    }
}

/// Renders and parses values through a `ValueFormatter`.
enum ValueFormatting {

    static func string(for node: PlistNode, formatter: ValueFormatter?) -> String {
        guard let formatter else { return PlistValueText.editingString(for: node) }
        switch formatter {
        case .decimal:
            return PlistValueText.editingString(for: node)
        case .hex:
            return "0x" + String(UInt64(bitPattern: integerValue(of: node)), radix: 16)
        case .osType:
            return fourCharCode(from: integerValue(of: node))
        case .storageSize:
            return byteCountFormatter.string(fromByteCount: integerValue(of: node))
        case .hms:
            return hmsString(from: integerValue(of: node))
        case .dataHex:
            return PlistValueText.hexString(from: dataValue(of: node))
        case .utf8:
            return String(decoding: dataValue(of: node), as: UTF8.self)
        case .ascii:
            return String(decoding: dataValue(of: node), as: UTF8.self)
        case .base64:
            return dataValue(of: node).base64EncodedString()
        case .uint16LE:
            return decodeIntegerArray(UInt16.self, from: dataValue(of: node), isLittleEndian: true)
        case .uint16BE:
            return decodeIntegerArray(UInt16.self, from: dataValue(of: node), isLittleEndian: false)
        case .uint32LE:
            return decodeIntegerArray(UInt32.self, from: dataValue(of: node), isLittleEndian: true)
        case .uint32BE:
            return decodeIntegerArray(UInt32.self, from: dataValue(of: node), isLittleEndian: false)
        case .float32LE:
            return decodeFloat32Array(from: dataValue(of: node), isLittleEndian: true)
        case .float32BE:
            return decodeFloat32Array(from: dataValue(of: node), isLittleEndian: false)
        }
    }

    static func kind(from text: String, formatter: ValueFormatter?, node: PlistNode) -> PlistNode.Kind {
        guard let formatter else { return PlistValueText.kind(from: text, preservingTypeOf: node) }
        switch formatter {
        case .decimal:
            return PlistValueText.kind(from: text, preservingTypeOf: node)
        case .hex:
            let cleaned = text.lowercased().replacingOccurrences(of: "0x", with: "").filter(\.isHexDigit)
            if let value = UInt64(cleaned, radix: 16) { return .integer(Int64(bitPattern: value)) }
            return node.kind
        case .osType:
            if let value = osTypeValue(text) { return .integer(value) }
            return node.kind
        case .storageSize, .hms:
            return node.kind
        case .uint16LE, .uint16BE, .uint32LE, .uint32BE, .float32LE, .float32BE:
            return node.kind
        case .dataHex:
            if let data = PlistValueText.data(fromHex: text) { return .data(data) }
            return node.kind
        case .utf8:
            return .data(Data(text.utf8))
        case .ascii:
            return .data(text.data(using: .ascii) ?? Data(text.utf8))
        case .base64:
            if let data = Data(base64Encoded: text) { return .data(data) }
            return node.kind
        }
    }

    // MARK: Value extraction

    private static func integerValue(of node: PlistNode) -> Int64 {
        switch node.kind {
        case .integer(let value): return value
        case .real(let value): return Int64(value)
        default: return 0
        }
    }

    private static func dataValue(of node: PlistNode) -> Data {
        if case .data(let value) = node.kind { return value }
        return Data()
    }

    // MARK: Number presentations

    nonisolated(unsafe) private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter
    }()

    private static func hmsString(from seconds: Int64) -> String {
        let negative = seconds < 0
        let total = abs(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%@%lld:%02lld:%02lld", negative ? "-" : "", h, m, s)
    }

    private static func fourCharCode(from value: Int64) -> String {
        let raw = UInt32(truncatingIfNeeded: value)
        let bytes = [
            UInt8((raw >> 24) & 0xff),
            UInt8((raw >> 16) & 0xff),
            UInt8((raw >> 8) & 0xff),
            UInt8(raw & 0xff)
        ]
        if bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7f }) {
            return String(decoding: bytes, as: UTF8.self)
        }
        return "0x" + String(format: "%08x", raw)
    }

    private static func osTypeValue(_ text: String) -> Int64? {
        let bytes = Array(text.utf8.prefix(4))
        guard !bytes.isEmpty else { return nil }
        var raw: UInt32 = 0
        for index in 0..<4 {
            let byte = index < bytes.count ? bytes[index] : 0x20
            raw = (raw << 8) | UInt32(byte)
        }
        return Int64(Int32(bitPattern: raw))
    }

    private static func decodeIntegerArray<T: FixedWidthInteger>(_ type: T.Type, from data: Data, isLittleEndian: Bool) -> String {
        let size = MemoryLayout<T>.size
        let count = data.count / size
        var values: [T] = []
        values.reserveCapacity(count)
        data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            for i in 0..<count {
                let val = base.load(fromByteOffset: i * size, as: T.self)
                values.append(isLittleEndian ? T(littleEndian: val) : T(bigEndian: val))
            }
        }
        return values.map { String(describing: $0) }.joined(separator: " ")
    }

    private static func decodeFloat32Array(from data: Data, isLittleEndian: Bool) -> String {
        let count = data.count / 4
        var values: [Float] = []
        values.reserveCapacity(count)
        data.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            for i in 0..<count {
                let raw = base.load(fromByteOffset: i * 4, as: UInt32.self)
                let u = isLittleEndian ? UInt32(littleEndian: raw) : UInt32(bigEndian: raw)
                values.append(Float(bitPattern: u))
            }
        }
        return values.map { String($0) }.joined(separator: " ")
    }
}
