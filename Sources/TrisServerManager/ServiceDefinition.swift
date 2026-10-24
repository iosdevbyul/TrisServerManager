import Foundation

enum ServiceKind: String, Codable, CaseIterable, Identifiable {
    case command = "Local Command"
    case dockerCompose = "Docker Compose"
    case homebrewPostgres = "Homebrew PostgreSQL"

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
    var healthCheckPath: String? = nil

    var effectiveHealthCheckPath: String? {
        if let healthCheckPath { return healthCheckPath.isEmpty ? nil : healthCheckPath }
        switch name {
        case "TrisAuthenticationServer": return "/hello"
        case "WakTrainerServer": return "/health"
        default: return nil
        }
    }

    func validate() -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a service name." }
        if workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Choose a working directory." }
        if kind != .homebrewPostgres && command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a command or Compose service name." }
        if kind == .homebrewPostgres && port == nil { return "PostgreSQL requires a port." }
        if let port, !(1...65535).contains(port) { return "Port must be between 1 and 65535." }
        if let healthCheckPath, !healthCheckPath.isEmpty {
            if kind != .command || port == nil { return "HTTP health checks require a local command and a port." }
            if !healthCheckPath.hasPrefix("/") || healthCheckPath.hasPrefix("//") || healthCheckPath.contains("?") || healthCheckPath.contains("#") {
                return "Health check must be a relative path starting with /, without query or fragment."
            }
        }
        return nil
    }
}
