import Foundation

/// Persistent proof that a listener was previously launched by TrisServerManager.
/// Never adopt a process based on its port or executable name alone.
struct ManagedProcessRecord: Codable {
    let serviceID: UUID
    let port: Int
    let pid: Int32
    let executable: String
    let startMarker: String

    static func recordsURL() -> URL {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/TrisServerManager", isDirectory: true)
        return folder.appendingPathComponent("managed-processes.json")
    }
}

enum ManagedProcessRegistry {
    static func load() -> [UUID: ManagedProcessRecord] {
        guard let data = try? Data(contentsOf: ManagedProcessRecord.recordsURL()),
              let records = try? JSONDecoder().decode([UUID: ManagedProcessRecord].self, from: data) else { return [:] }
        return records
    }

    static func save(_ records: [UUID: ManagedProcessRecord]) {
        let url = ManagedProcessRecord.recordsURL()
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(records)
            try data.write(to: url, options: .atomic)
        } catch {
            // Persistence failure prevents future automatic recovery, never causes a blind kill.
        }
    }
}
