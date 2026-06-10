import SwiftUI

/// The bottom pane: the sync controls plus the editable source text view.
struct SourcePane: View {
    @ObservedObject var document: PlistDocument
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.undoManager) private var undoManager

    private var autoSync: Binding<Bool> {
        Binding(
            get: { document.autoSyncText },
            set: { newValue in
                document.autoSyncText = newValue
                if newValue { document.regenerateSourceText() }
            }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { document.syncError != nil },
            set: { presented in if !presented { document.syncError = nil } }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            syncBar
            Divider()
            SourceTextView(text: $document.sourceText, format: document.format)
        }
        .alert("error.sync.title", isPresented: errorPresented, presenting: document.syncError) { _ in
            Button("action.ok", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var syncBar: some View {
        HStack(spacing: 12) {
            Button {
                document.syncOutlineFromText(undoManager: undoManager)
            } label: {
                Label("sync.outline", systemImage: "arrow.up")
            }

            Spacer()

            Toggle("sync.auto", isOn: autoSync)
                .toggleStyle(.checkbox)

            Button {
                document.regenerateSourceText()
            } label: {
                Label("sync.text", systemImage: "arrow.down")
            }
            .disabled(document.autoSyncText)
        }
        .labelStyle(.titleAndIcon)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
