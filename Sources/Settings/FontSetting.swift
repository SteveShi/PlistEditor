import SwiftUI
import AppKit

/// A persisted font choice (PostScript name + size). An empty name means the
/// system font.
struct FontSetting: Equatable, Sendable {
    var name: String
    var size: Double

    static let systemName = ""

    var nsFont: NSFont {
        if name.isEmpty { return .systemFont(ofSize: size) }
        return NSFont(name: name, size: size) ?? .systemFont(ofSize: size)
    }

    var swiftUIFont: Font {
        Font(nsFont)
    }

    /// Human-readable label, e.g. "Menlo Regular - 12.0".
    var displayName: String {
        let font = nsFont
        let base = font.displayName ?? font.fontName
        return "\(base) - \(String(format: "%.1f", size))"
    }

    init(name: String = FontSetting.systemName, size: Double) {
        self.name = name
        self.size = size
    }

    init(_ font: NSFont) {
        self.name = font.fontName
        self.size = Double(font.pointSize)
    }
}

extension Color {
    /// Parses "#RRGGBB" / "#RRGGBBAA"; falls back to the supplied default.
    init(hex: String, default fallback: Color) {
        var string = hex.trimmingCharacters(in: .whitespaces)
        if string.hasPrefix("#") { string.removeFirst() }
        guard let value = UInt64(string, radix: 16) else { self = fallback; return }
        let r, g, b, a: Double
        switch string.count {
        case 6:
            r = Double((value >> 16) & 0xff) / 255
            g = Double((value >> 8) & 0xff) / 255
            b = Double(value & 0xff) / 255
            a = 1
        case 8:
            r = Double((value >> 24) & 0xff) / 255
            g = Double((value >> 16) & 0xff) / 255
            b = Double((value >> 8) & 0xff) / 255
            a = Double(value & 0xff) / 255
        default:
            self = fallback
            return
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
