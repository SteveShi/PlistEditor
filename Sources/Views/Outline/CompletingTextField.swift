import SwiftUI
import AppKit

/// A plain inline text field with key autocompletion driven by the active
/// structure definition. Wraps `NSTextField` to use AppKit's native completion
/// list, which SwiftUI's `TextField` does not expose.
struct CompletingTextField: NSViewRepresentable {
    let value: String
    let completions: (String) -> [String]
    let onCommit: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: value)
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = AppSettings.shared.outlineFont.nsFont
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        field.font = AppSettings.shared.outlineFont.nsFont
        if !context.coordinator.isEditing, field.stringValue != value {
            field.stringValue = value
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CompletingTextField
        var isEditing = false
        private var isCompleting = false

        init(_ parent: CompletingTextField) { self.parent = parent }

        func controlTextDidBeginEditing(_ obj: Notification) {
            isEditing = true
        }

        func controlTextDidChange(_ obj: Notification) {
            guard !isCompleting,
                  let field = obj.object as? NSTextField,
                  let editor = field.currentEditor() as? NSTextView,
                  !field.stringValue.isEmpty else { return }
            isCompleting = true
            editor.complete(nil)
            isCompleting = false
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            isEditing = false
            guard let field = obj.object as? NSTextField else { return }
            if field.stringValue != parent.value {
                parent.onCommit(field.stringValue)
            }
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            completions words: [String],
            forPartialWordRange charRange: NSRange,
            indexOfSelectedItem index: UnsafeMutablePointer<Int>
        ) -> [String] {
            let partial = (textView.string as NSString).substring(with: charRange)
            return parent.completions(partial)
        }
    }
}
