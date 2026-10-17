import Foundation
import Observation

@MainActor
@Observable
final class ServiceStore {
    private(set) var services: [ServiceDefinition] = []
    var errorMessage: String?
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TrisServerManager", isDirectory: true)
        self.fileURL = fileURL ?? directory.appendingPathComponent("services.json")
        load()
    }

    func add(_ service: ServiceDefinition) {
        guard let message = service.validate() else {
            guard !services.contains(where: { sameRegistration($0, service) }) else {
                errorMessage = "This service command is already registered in this directory."
                return
            }
            services.append(service)
            persist()
            return
        }
        errorMessage = message
    }

    func update(_ service: ServiceDefinition) {
        guard let message = service.validate() else {
            guard let index = services.firstIndex(where: { $0.id == service.id }) else { return }
            guard !services.contains(where: { $0.id != service.id && sameRegistration($0, service) }) else {
                errorMessage = "This service command is already registered in this directory."
                return
            }
            services[index] = service
            persist()
            return
        }
        errorMessage = message
    }

    func delete(_ id: UUID) {
        services.removeAll { $0.id == id }
        persist()
    }

    private func sameRegistration(_ lhs: ServiceDefinition, _ rhs: ServiceDefinition) -> Bool {
        lhs.kind == rhs.kind &&
        URL(fileURLWithPath: lhs.workingDirectory).resolvingSymlinksInPath().standardizedFileURL.path ==
        URL(fileURLWithPath: rhs.workingDirectory).resolvingSymlinksInPath().standardizedFileURL.path &&
        lhs.command.trimmingCharacters(in: .whitespacesAndNewlines) == rhs.command.trimmingCharacters(in: .whitespacesAndNewlines) &&
        lhs.port == rhs.port
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do { services = try JSONDecoder().decode([ServiceDefinition].self, from: Data(contentsOf: fileURL)) }
        catch { errorMessage = "Could not load services: \(error.localizedDescription)" }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(services)
            try data.write(to: fileURL, options: .atomic)
        } catch { errorMessage = "Could not save services: \(error.localizedDescription)" }
    }
}
