import Foundation

/// A non-destructive command planner for Homebrew-managed PostgreSQL 16.
/// PostgreSQL must already be installed and its data directory initialized.
/// This type never installs packages, initializes clusters, deletes data, or
/// acts on Docker containers.
enum HomebrewPostgres {
    enum ConfigurationError: LocalizedError, Equatable {
        case invalidPort
        case emptyDataDirectory
        case missingDataDirectory
        case uninitializedCluster
        case missingExecutable

        var errorDescription: String? {
            switch self {
            case .invalidPort: return "PostgreSQL port must be between 1 and 65535."
            case .emptyDataDirectory: return "Choose an existing PostgreSQL data directory."
            case .missingDataDirectory: return "The PostgreSQL data directory does not exist."
            case .uninitializedCluster: return "The directory is not an initialized PostgreSQL cluster (PG_VERSION is missing)."
            case .missingExecutable: return "PostgreSQL 16 pg_ctl was not found. Install postgresql@16 with Homebrew."
            }
        }
    }

    struct Cluster: Equatable {
        let dataDirectory: String
        let port: Int

        func validate(fileManager: FileManager = .default) throws {
            guard (1...65535).contains(port) else { throw ConfigurationError.invalidPort }
            guard !dataDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ConfigurationError.emptyDataDirectory
            }
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: dataDirectory, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw ConfigurationError.missingDataDirectory
            }
            guard fileManager.fileExists(atPath: URL(fileURLWithPath: dataDirectory).appendingPathComponent("PG_VERSION").path) else {
                throw ConfigurationError.uninitializedCluster
            }
        }
    }

    struct Command: Equatable {
        let executable: String
        let arguments: [String]
    }

    static let executableCandidates = [
        "/opt/homebrew/opt/postgresql@16/bin/pg_ctl",
        "/usr/local/opt/postgresql@16/bin/pg_ctl"
    ]

    static func executablePath(fileManager: FileManager = .default) -> String? {
        executableCandidates.first { fileManager.isExecutableFile(atPath: $0) }
    }

    static func status(_ cluster: Cluster, executable: String) -> Command {
        Command(executable: executable, arguments: ["-D", cluster.dataDirectory, "status"])
    }

    static func start(_ cluster: Cluster, executable: String) -> Command {
        // -o passes server-only options, not a shell command. Avoid shell interpolation.
        Command(executable: executable, arguments: [
            "-D", cluster.dataDirectory, "-o", "-h 127.0.0.1 -p \(cluster.port)", "-w", "start"
        ])
    }

    static func stop(_ cluster: Cluster, executable: String) -> Command {
        Command(executable: executable, arguments: ["-D", cluster.dataDirectory, "-m", "fast", "-w", "stop"])
    }

    static func run(_ command: Command) async throws -> (exitCode: Int32, output: String) {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command.executable)
            process.arguments = command.arguments
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            try process.run()
            // Do not buffer unbounded output or block on a full pipe.
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }.value
    }
}
