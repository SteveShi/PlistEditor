import SwiftUI

/// A single search hit: which node, and whether the key or value matched.
struct FindMatch: Equatable {
    enum Field { case key, value }
    let nodeID: PlistNode.ID
    let field: Field
}

/// The find/replace bar shown above the outline.
struct FindBar: View {
    @Binding var query: String
    @Binding var replacement: String
    let matchCount: Int
    let currentIndex: Int
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onReplace: () -> Void
    let onReplaceAll: () -> Void
    let onClose: () -> Void

    @FocusState private var queryFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("find.placeholder", text: $query)
                    .textFieldStyle(.plain)
                    .focused($queryFocused)
                    .frame(minWidth: 120)
                Text(verbatim: matchCount > 0 ? "\(currentIndex + 1)/\(matchCount)" : "0/0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(4)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            Button(action: onPrevious) { Image(systemName: "chevron.up") }
                .help("find.previous")
                .disabled(matchCount == 0)
            Button(action: onNext) { Image(systemName: "chevron.down") }
                .help("find.next")
                .disabled(matchCount == 0)

            Divider().frame(height: 16)

            TextField("find.replacePlaceholder", text: $replacement)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 120)
            Button("find.replace", action: onReplace)
                .disabled(matchCount == 0)
            Button("find.replaceAll", action: onReplaceAll)
                .disabled(matchCount == 0)

            Spacer()

            Button(action: onClose) { Image(systemName: "xmark") }
                .help("find.close")
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .onAppear { queryFocused = true }
        .onExitCommand(perform: onClose)
    }
}
