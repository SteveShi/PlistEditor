import Foundation

enum PreferenceLocationType: Hashable, Sendable {
    case user
    case system
    case containers
    case groups
    case custom(URL)
}

struct PreferenceLocation: Identifiable, Hashable, Sendable {
    let id: String
    let type: PreferenceLocationType
    let displayNameKey: String
    let url: URL

    static var defaultLocations: [PreferenceLocation] {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        var locs: [PreferenceLocation] = []

        // User
        let userURL = home.appendingPathComponent("Library/Preferences")
        locs.append(PreferenceLocation(id: "user", type: .user, displayNameKey: "browser.location.user", url: userURL))

        // System
        let systemURL = URL(fileURLWithPath: "/Library/Preferences")
        locs.append(PreferenceLocation(id: "system", type: .system, displayNameKey: "browser.location.system", url: systemURL))

        // Containers
        let containersURL = home.appendingPathComponent("Library/Containers")
        locs.append(PreferenceLocation(id: "containers", type: .containers, displayNameKey: "browser.location.containers", url: containersURL))

        // Groups
        let groupsURL = home.appendingPathComponent("Library/Group Containers")
        locs.append(PreferenceLocation(id: "groups", type: .groups, displayNameKey: "browser.location.groups", url: groupsURL))

        return locs
    }
}

struct PreferenceFile: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let url: URL
    let modificationDate: Date
    let size: Int64
}

final class PreferenceScanner: Sendable {
    static func scan(location: PreferenceLocation, extensions: [String]) async -> [PreferenceFile] {
        let fileManager = FileManager.default
        var urlsToScan: [URL] = []

        switch location.type {
        case .user, .system, .custom:
            urlsToScan.append(location.url)

        case .containers:
            guard let enumerator = fileManager.enumerator(
                at: location.url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            ) else { break }
            while let containerURL = enumerator.nextObject() as? URL {
                let prefsURL = containerURL.appendingPathComponent("Data/Library/Preferences")
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: prefsURL.path, isDirectory: &isDir), isDir.boolValue {
                    urlsToScan.append(prefsURL)
                }
            }

        case .groups:
            guard let enumerator = fileManager.enumerator(
                at: location.url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            ) else { break }
            while let groupURL = enumerator.nextObject() as? URL {
                let prefsURL = groupURL.appendingPathComponent("Library/Preferences")
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: prefsURL.path, isDirectory: &isDir), isDir.boolValue {
                    urlsToScan.append(prefsURL)
                }
            }
        }

        var files: [PreferenceFile] = []
        let lowercasedExts = extensions.map { $0.lowercased() }

        for dirURL in urlsToScan {
            guard let enumerator = fileManager.enumerator(
                at: dirURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            ) else { continue }

            while let fileURL = enumerator.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                if lowercasedExts.isEmpty || lowercasedExts.contains(ext) {
                    let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                    let date = resourceValues?.contentModificationDate ?? Date.distantPast
                    let size = Int64(resourceValues?.fileSize ?? 0)
                    
                    files.append(PreferenceFile(
                        id: fileURL.path,
                        name: fileURL.lastPathComponent,
                        url: fileURL,
                        modificationDate: date,
                        size: size
                    ))
                }
            }
        }

        return files.sorted { $0.modificationDate > $1.modificationDate }
    }
}
