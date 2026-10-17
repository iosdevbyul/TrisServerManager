import Foundation

struct DiscoveredService: Identifiable {
    let definition: ServiceDefinition
    let note: String
    let isReady: Bool
    var id: String { definition.workingDirectory + "|" + definition.kind.rawValue + "|" + definition.command }
}

enum ProjectDiscovery {
    static func scan(root: URL, existing: [ServiceDefinition]) -> [DiscoveredService] {
        let fm = FileManager.default
        let root = root.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else { return [] }
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isHiddenKey]
        guard let iterator = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var candidates: [DiscoveredService] = []
        let skipped = Set([".git", "node_modules", ".build", ".venv", "venv", "DerivedData", "build", "dist", "Pods"])
        var visited = 0
        for case let url as URL in iterator {
            visited += 1
            if visited > 20_000 { break }
            let values = try? url.resourceValues(forKeys: keys)
            if values?.isSymbolicLink == true { iterator.skipDescendants(); continue }
            guard values?.isDirectory == true else { continue }
            if skipped.contains(url.lastPathComponent) { iterator.skipDescendants(); continue }
            let name = url.lastPathComponent
            if let preset = DevelopmentServicePreset.known.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                let draft = ServiceDefinition(name: preset.name, kind: .command, workingDirectory: url.resolvingSymlinksInPath().standardizedFileURL.path, command: preset.command, port: preset.port, group: preset.group)
                candidates.append(DiscoveredService(definition: draft, note: preset.command.isEmpty ? "Review: launch command unknown" : "Known preset; verify command and port", isReady: !preset.command.isEmpty))
            } else {
                let suggestions = LocalProjectDetector.suggestions(in: url)
                if let suggestion = suggestions.first(where: { $0.id == "npm-dev" || $0.id == "npm-start" }) {
                    let draft = ServiceDefinition(name: name, kind: .command, workingDirectory: url.path, command: suggestion.command, port: nil, group: name)
                    candidates.append(DiscoveredService(definition: draft, note: "Detected npm script; verify whether it starts a server and check port", isReady: true))
                } else if !suggestions.isEmpty {
                    let draft = ServiceDefinition(name: name, kind: .command, workingDirectory: url.path, command: "", port: nil, group: name)
                    candidates.append(DiscoveredService(definition: draft, note: "Review: project found but executable command unknown", isReady: false))
                }
            }
        }
        // The root directory may itself be a project; include it without walking its parent.
        if candidates.isEmpty {
            let suggestions = LocalProjectDetector.suggestions(in: root)
            if let suggestion = suggestions.first(where: { $0.id == "npm-dev" || $0.id == "npm-start" }) {
                candidates.append(DiscoveredService(definition: .init(name: root.lastPathComponent, kind: .command, workingDirectory: root.path, command: suggestion.command, port: nil, group: root.lastPathComponent), note: "Detected npm script; verify command and port", isReady: true))
            }
        }
        func normalizedDirectory(_ service: ServiceDefinition) -> String {
            URL(fileURLWithPath: service.workingDirectory).resolvingSymlinksInPath().standardizedFileURL.path
        }
        return candidates.filter { candidate in
            !existing.contains { service in
                service.kind == candidate.definition.kind &&
                normalizedDirectory(service) == normalizedDirectory(candidate.definition) &&
                service.command.trimmingCharacters(in: .whitespacesAndNewlines) ==
                    candidate.definition.command.trimmingCharacters(in: .whitespacesAndNewlines) &&
                (service.kind == .dockerCompose || service.port == candidate.definition.port)
            }
        }.sorted { $0.definition.workingDirectory < $1.definition.workingDirectory }
    }
}
