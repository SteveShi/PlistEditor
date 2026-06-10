import SwiftUI
import AppKit

struct PreferenceBrowserView: View {
    @State private var locations: [PreferenceLocation] = PreferenceLocation.defaultLocations
    @State private var customLocations: [PreferenceLocation] = []
    @State private var selectedLocation: PreferenceLocation? = nil
    
    @State private var files: [PreferenceFile] = []
    @State private var isScanning = false
    @State private var searchQuery = ""
    @State private var sortOrder = [KeyPathComparator(\PreferenceFile.modificationDate, order: .reverse)]
    
    @ObservedObject private var settings = AppSettings.shared

    private var allLocations: [PreferenceLocation] {
        locations + customLocations
    }

    private var filteredFiles: [PreferenceFile] {
        let sorted = files.sorted(using: sortOrder)
        if searchQuery.isEmpty {
            return sorted
        }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        NavigationSplitView {
            List(allLocations, selection: $selectedLocation) { loc in
                NavigationLink(value: loc) {
                    HStack {
                        Image(systemName: icon(for: loc.type))
                            .foregroundColor(.accentColor)
                        if case .custom(let url) = loc.type {
                            Text(url.lastPathComponent)
                        } else {
                            Text(LocalizedStringKey(loc.displayNameKey))
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: addCustomFolder) {
                    Label("browser.addFolder", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding()
            }
            .navigationTitle("browser.title")
        } detail: {
            if let loc = selectedLocation {
                VStack(spacing: 0) {
                    if isScanning {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    } else if files.isEmpty {
                        Spacer()
                        ContentUnavailableView {
                            Label("browser.empty.files", systemImage: "doc.text.magnifyingglass")
                        } description: {
                            Text("browser.empty.files.desc")
                        }
                        Spacer()
                    } else {
                        Table(filteredFiles, selection: .constant(Set<PreferenceFile.ID>()), sortOrder: $sortOrder) {
                            TableColumn("browser.column.name", value: \.name) { file in
                                Text(file.name)
                                    .font(settings.browserFont.swiftUIFont)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        open(file: file)
                                    }
                                    .contextMenu {
                                        Button("browser.revealInFinder") {
                                            NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                        }
                                    }
                            }
                            TableColumn("browser.column.date", value: \.modificationDate) { file in
                                Text(dateFormatter.string(from: file.modificationDate))
                                    .foregroundColor(.secondary)
                                    .font(settings.browserFont.swiftUIFont)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        open(file: file)
                                    }
                            }
                            TableColumn("browser.column.size", value: \.size) { file in
                                Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .binary))
                                    .foregroundColor(.secondary)
                                    .font(settings.browserFont.swiftUIFont)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .contentShape(Rectangle())
                                    .onTapGesture(count: 2) {
                                        open(file: file)
                                    }
                            }
                        }
                        .environment(\.defaultMinListRowHeight, 24)
                    }
                }
                .searchable(text: $searchQuery, prompt: "browser.search")
                .navigationTitle(title(for: loc))
                .task(id: loc) {
                    await scan(location: loc)
                }
                .onChange(of: settings.browsingExtensions) {
                    Task {
                        await scan(location: loc)
                    }
                }
            } else {
                Text("browser.empty")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }

    private func icon(for type: PreferenceLocationType) -> String {
        switch type {
        case .user: return "person.crop.circle"
        case .system: return "cpu"
        case .containers: return "shippingbox"
        case .groups: return "person.3"
        case .custom: return "folder"
        }
    }

    private func title(for loc: PreferenceLocation) -> String {
        if case .custom(let url) = loc.type {
            return url.lastPathComponent
        }
        return NSLocalizedString(loc.displayNameKey, comment: "")
    }

    private func scan(location: PreferenceLocation) async {
        isScanning = true
        files = await PreferenceScanner.scan(location: location, extensions: settings.browsingExtensions)
        isScanning = false
    }

    private func addCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("settings.choose", comment: "")
        
        if panel.runModal() == .OK, let url = panel.url {
            let loc = PreferenceLocation(
                id: url.path,
                type: .custom(url),
                displayNameKey: "",
                url: url
            )
            customLocations.append(loc)
            selectedLocation = loc
        }
    }

    private func open(file: PreferenceFile) {
        NSDocumentController.shared.openDocument(withContentsOf: file.url, display: true) { _, _, _ in
            // Done
        }
    }
}
