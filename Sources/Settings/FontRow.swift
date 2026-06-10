import SwiftUI
import AppKit

/// A labeled, read-only font field with a "Choose…" button that opens the
/// system font panel and writes the chosen font back into the binding.
struct FontRow: View {
    let titleKey: LocalizedStringKey
    @Binding var font: FontSetting

    @State private var controller = FontPanelController()

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Text(verbatim: font.displayName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 5))
                Button("settings.choose") {
                    controller.current = font.nsFont
                    controller.onChange = { newFont in font = FontSetting(newFont) }
                    controller.show()
                }
            }
        } label: {
            Text(titleKey)
        }
    }
}

/// Bridges the shared `NSFontManager` / `NSFontPanel` to a SwiftUI binding.
private final class FontPanelController: NSObject {
    var current: NSFont = .systemFont(ofSize: NSFont.systemFontSize)
    var onChange: (NSFont) -> Void = { _ in }

    func show() {
        let manager = NSFontManager.shared
        manager.target = self
        manager.setSelectedFont(current, isMultiple: false)
        manager.orderFrontFontPanel(nil)
    }

    @objc func changeFont(_ sender: NSFontManager?) {
        guard let sender else { return }
        current = sender.convert(current)
        onChange(current)
    }
}
