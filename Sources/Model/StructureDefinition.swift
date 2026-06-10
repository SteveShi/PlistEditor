import Foundation

/// A structure definition describes the well-known keys of a particular plist
/// file type (e.g. Info.plist), enabling key autocompletion and descriptions.
/// Definitions are bundled as JSON; this is a lightweight subset of PlistEdit
/// Pro's Xcode-plugin-based definitions.
struct StructureDefinition: Codable, Sendable {
    let name: String
    let fileNamePatterns: [String]
    let keys: [DefinitionKey]

    /// True if this definition applies to the given file name (glob patterns,
    /// case-insensitive).
    func matches(fileName: String) -> Bool {
        fileNamePatterns.contains { pattern in
            pattern.caseInsensitiveCompare(fileName) == .orderedSame
                || fnmatch(pattern, fileName, FNM_CASEFOLD) == 0
        }
    }

    func description(for key: String) -> String? {
        keys.first { $0.key == key }?.description
    }

    var keyNames: [String] { keys.map(\.key) }
}

struct DefinitionKey: Codable, Sendable {
    let key: String
    let type: String?
    let description: String?
}

/// Loads and matches the structure definitions bundled with the app.
@MainActor
final class StructureDefinitionStore {
    static let shared = StructureDefinitionStore()

    let definitions: [StructureDefinition]

    private init() {
        var loaded: [StructureDefinition] = []
        let decoder = JSONDecoder()
        for url in Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [] {
            if let data = try? Data(contentsOf: url),
               let definition = try? decoder.decode(StructureDefinition.self, from: data) {
                loaded.append(definition)
            }
        }
        definitions = loaded
    }

    func definition(forFileNamed name: String?) -> StructureDefinition? {
        guard let name else { return nil }
        return definitions.first { $0.matches(fileName: name) }
    }
}
