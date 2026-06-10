import SwiftUI
import AppKit

/// An editable, syntax-highlighted text view for the property-list source. Wraps
/// `NSTextView` because SwiftUI has no native rich-text editor with the control
/// needed for tag coloring. Font and tag color come from `AppSettings`.
struct SourceTextView: NSViewRepresentable {
    @Binding var text: String
    let format: PlistFormat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.string = text
        applyStyle(to: textView, context: context)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        let key = styleKey
        if textView.string != text {
            textView.string = text
            applyStyle(to: textView, context: context)
        } else if context.coordinator.lastStyleKey != key {
            applyStyle(to: textView, context: context)
        }
    }

    private var styleKey: String {
        let settings = AppSettings.shared
        let font = settings.textFont
        return "\(format.rawValue)|\(font.name)|\(font.size)|\(settings.colorXMLTags)|\(settings.xmlTagColor.hexString)"
    }

    @MainActor
    private func applyStyle(to textView: NSTextView, context: Context) {
        let settings = AppSettings.shared
        let font = settings.textFont.nsFont
        textView.font = font
        SourceHighlighter.apply(
            to: textView.textStorage,
            format: format,
            baseFont: font,
            colorTags: settings.colorXMLTags,
            tagColor: NSColor(settings.xmlTagColor)
        )
        context.coordinator.lastStyleKey = styleKey
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SourceTextView
        var lastStyleKey: String = ""

        init(_ parent: SourceTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            let settings = AppSettings.shared
            SourceHighlighter.apply(
                to: textView.textStorage,
                format: parent.format,
                baseFont: settings.textFont.nsFont,
                colorTags: settings.colorXMLTags,
                tagColor: NSColor(settings.xmlTagColor)
            )
        }
    }
}

/// Applies lightweight regex-based syntax coloring to the source text.
@MainActor
enum SourceHighlighter {
    static func apply(to storage: NSTextStorage?, format: PlistFormat, baseFont: NSFont, colorTags: Bool, tagColor: NSColor) {
        guard let storage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        let text = storage.string

        storage.beginEditing()
        storage.setAttributes([.font: baseFont, .foregroundColor: NSColor.textColor], range: fullRange)

        switch format.textRendering {
        case .xml, .openStep:
            if colorTags {
                color(storage, text, pattern: "</?[^>]+>", color: tagColor)
                color(storage, text, pattern: "<!--[\\s\\S]*?-->", color: .systemGray)
            }
        case .json:
            color(storage, text, pattern: "\"(\\\\.|[^\"\\\\])*\"", color: .systemRed)
            color(storage, text, pattern: "\\b(true|false|null)\\b", color: .systemPurple)
            color(storage, text, pattern: "-?\\d+(\\.\\d+)?([eE][+-]?\\d+)?", color: .systemBlue)
        }

        storage.endEditing()
    }

    private static func color(_ storage: NSTextStorage, _ text: String, pattern: String, color: NSColor) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(location: 0, length: (text as NSString).length)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            if let match {
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
    }
}
