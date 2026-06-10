import SwiftUI

/// The Settings window (⌘,) with General, Display, and Browsing tabs, modeled
/// on PlistEdit Pro's preferences.
struct SettingsView: View {
    private enum Tab: Hashable { case general, display, browsing }
    @State private var selection: Tab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsTab()
                .tabItem {
                    Label("settings.tab.general", systemImage: "gearshape")
                }
                .tag(Tab.general)
            DisplaySettingsTab()
                .tabItem {
                    Label("settings.tab.display", systemImage: "paintpalette")
                }
                .tag(Tab.display)
            BrowsingSettingsTab()
                .tabItem {
                    Label("settings.tab.browsing", systemImage: "magnifyingglass")
                }
                .tag(Tab.browsing)
        }
        .frame(width: 560, height: 470)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showRestart = false

    var body: some View {
        Form {
            Picker("settings.language", selection: $settings.language) {
                Text("settings.language.system").tag(AppLanguage.system)
                ForEach(AppLanguage.all.filter { $0.code != nil }) { language in
                    Text(verbatim: language.nativeName).tag(language)
                }
            }
            .onChange(of: settings.language) { showRestart = true }

            Picker("settings.general.defaultFormat", selection: $settings.defaultFormat) {
                ForEach(PlistFormat.selectable) { format in
                    Text(verbatim: format.displayName).tag(format)
                }
            }

            Picker("settings.general.activated", selection: $settings.activateAction) {
                Text("settings.general.activated.new").tag(ActivateAction.createDocument)
                Text("settings.general.activated.nothing").tag(ActivateAction.doNothing)
            }
            .pickerStyle(.radioGroup)

            Picker("settings.general.opening", selection: $settings.expandOnOpen) {
                Text("settings.general.opening.root").tag(ExpandOnOpen.rootOnly)
                Text("settings.general.opening.all").tag(ExpandOnOpen.allChildren)
            }
            .pickerStyle(.radioGroup)

            Toggle("settings.general.autosave", isOn: $settings.enableAutosaving)

            Section {
                Picker("settings.general.defaultClass", selection: $settings.defaultClass) {
                    ForEach(PlistType.menuOrder) { type in
                        Text(verbatim: type.displayName).tag(type)
                    }
                }
                Toggle("settings.general.askRevert", isOn: $settings.askToRevert)
                Toggle("settings.general.rememberFormatter", isOn: $settings.rememberFormatterByKey)
                Toggle("settings.general.returnEdits", isOn: $settings.returnEditsNextRow)
            }
        }
        .formStyle(.grouped)
        .alert("settings.restart.title", isPresented: $showRestart) {
            Button("settings.restart.now") { LanguageController.relaunch() }
            Button("settings.restart.later", role: .cancel) {}
        } message: {
            Text("settings.restart.message")
        }
    }
}

// MARK: - Display

private struct DisplaySettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            FontRow(titleKey: "settings.display.outlineFont", font: $settings.outlineFont)
            FontRow(titleKey: "settings.display.textFont", font: $settings.textFont)
            FontRow(titleKey: "settings.display.browserFont", font: $settings.browserFont)

            Section("settings.display.sortOptions") {
                Toggle("settings.display.sort.caseSensitive", isOn: $settings.sortCaseSensitive)
                Toggle("settings.display.sort.numeric", isOn: $settings.sortNumeric)
            }

            Section("settings.display.xmlDisplay") {
                Toggle("settings.display.colorTags", isOn: $settings.colorXMLTags)
                ColorPicker("settings.display.colorTags", selection: $settings.xmlTagColor, supportsOpacity: false)
                    .labelsHidden()
                    .disabled(!settings.colorXMLTags)
            }

            Section("settings.display.jsonFormatting") {
                Picker("settings.display.json.displayAs", selection: $settings.jsonDisplayIndented) {
                    Text("settings.json.indented").tag(true)
                    Text("settings.json.condensed").tag(false)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()

                Picker("settings.display.json.saveAs", selection: $settings.jsonSaveIndented) {
                    Text("settings.json.indented").tag(true)
                    Text("settings.json.condensed").tag(false)
                }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Browsing

private struct ExtensionItem: Identifiable, Equatable {
    let id = UUID()
    var value: String
}

private struct BrowsingSettingsTab: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var items: [ExtensionItem] = []
    @State private var selection: ExtensionItem.ID?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("settings.browsing.title").fontWeight(.medium)
                List(selection: $selection) {
                    ForEach($items) { $item in
                        TextField(text: $item.value) { EmptyView() }
                            .textFieldStyle(.plain)
                    }
                }
                .border(.separator)
                HStack(spacing: 0) {
                    Button { addItem() } label: { Image(systemName: "plus").frame(width: 24) }
                    Button { removeItem() } label: { Image(systemName: "minus").frame(width: 24) }
                        .disabled(selection == nil)
                }
                .buttonStyle(.bordered)
            }
            .frame(width: 260)

            Text("settings.browsing.description")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 28)
        }
        .padding()
        .onAppear { items = settings.browsingExtensions.map { ExtensionItem(value: $0) } }
        .onChange(of: items) { persist() }
    }

    private func addItem() {
        let item = ExtensionItem(value: "")
        items.append(item)
        selection = item.id
    }

    private func removeItem() {
        items.removeAll { $0.id == selection }
        selection = nil
    }

    private func persist() {
        settings.browsingExtensions = items
            .map { $0.value.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }
}
