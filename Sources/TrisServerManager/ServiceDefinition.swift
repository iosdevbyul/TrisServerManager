import Foundation

enum ServiceKind: String, Codable, CaseIterable, Identifiable {
    case command = "Local Command"
    case dockerCompose = "Docker Compose"

    var id: String { rawValue }
}

struct ServiceDefinition: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var kind: ServiceKind
    var workingDirectory: String
    var command: String
    var port: Int?
    var group: String

    func validate() -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a service name." }
        if workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Choose a working directory." }
        if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a command or Compose service name." }
        if let port, !(1...65535).contains(port) { return "Port must be between 1 and 65535." }
        return nil
    }
}
