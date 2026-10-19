import Foundation
import Darwin

/// A snapshot, not an authorization: identities must be reverified before any stop.
struct PortConflict: Identifiable {
    let id = UUID()
    let service: ServiceDefinition
    let port: Int
    let targets: [PortConflictTarget]
}

struct PortConflictTarget: Identifiable {
    enum Kind { case local, docker }
    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let pid: Int32?
    let birth: String?
    let containerID: String?
}

/// Read-only discovery and explicitly authorized shutdown of individual port owners.
/// Never signal Docker Desktop itself; stop mapped containers via docker stop.
enum PortConflictInspector {
    static func inspect(port: Int, service: ServiceDefinition) async -> PortConflict {
        let targets = await Task.detached(priority: .utility) { () -> [PortConflictTarget] in
            let mapped = dockerTargets(port: port)
            let pids = output("/usr/sbin/lsof", ["-nP", "-t", "-iTCP:\(port)", "-sTCP:LISTEN"])?
                .split(whereSeparator: \.isNewline).compactMap { Int32($0) } ?? []
            var owners = mapped
            for pid in Set(pids) where pid > 1 {
                guard let uidText = output("/bin/ps", ["-p", String(pid), "-o", "uid="]),
                      UInt32(uidText.trimmingCharacters(in: .whitespacesAndNewlines)) == getuid(),
                      let birth = output("/bin/ps", ["-p", String(pid), "-o", "lstart="]),
                      let command = output("/bin/ps", ["-p", String(pid), "-o", "command="]) else {
                    owners.append(.init(id: "unknown-\(pid)", kind: .local,
                        title: "Unverified process \(pid)", detail: "Cannot verify ownership; not stoppable",
                        pid: nil, birth: nil, containerID: nil))
                    continue
                }
                let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains("/Applications/Docker.app/") || trimmed.contains("com.docker.backend") {
                    // Docker's host listener is shared. Never SIGTERM it.
                    if mapped.isEmpty {
                        owners.append(.init(id: "docker-proxy-\(pid)", kind: .local,
                            title: "Docker Desktop (PID \(pid))",
                            detail: "Docker port mapping not identified; cannot stop safely",
                            pid: nil, birth: nil, containerID: nil))
                    }
                    continue
                }
                owners.append(.init(id: "pid-\(pid)", kind: .local,
                    title: "PID \(pid) — \(trimmed)", detail: "Local process · PID \(pid)",
                    pid: pid, birth: birth.trimmingCharacters(in: .whitespacesAndNewlines), containerID: nil))
            }
            return owners
        }.value
        return PortConflict(service: service, port: port, targets: targets)
    }

    /// Refuse a changed PID, stale birth marker, different container mapping,
    /// or a process that is not owned by the current macOS user.
    static func stop(_ target: PortConflictTarget, port: Int) async -> Bool {
        await Task.detached(priority: .utility) {
            switch target.kind {
            case .docker:
                guard let containerID = target.containerID,
                      dockerTargets(port: port).contains(where: { $0.containerID == containerID }),
                      output("/usr/local/bin/docker", ["--version"]) != nil ||
                        output("/opt/homebrew/bin/docker", ["--version"]) != nil else { return false }
                guard let cli = dockerExecutable() else { return false }
                return output(cli, ["stop", containerID], timeout: 20) != nil
            case .local:
                guard let pid = target.pid, let birth = target.birth, pid > 1,
                      let owner = output("/bin/ps", ["-p", String(pid), "-o", "uid="]),
                      UInt32(owner.trimmingCharacters(in: .whitespacesAndNewlines)) == getuid(),
                      let currentBirth = output("/bin/ps", ["-p", String(pid), "-o", "lstart="]),
                      currentBirth.trimmingCharacters(in: .whitespacesAndNewlines) == birth,
                      let ports = output("/usr/sbin/lsof", ["-nP", "-t", "-iTCP:\(port)", "-sTCP:LISTEN"]),
                      ports.split(whereSeparator: \.isNewline).contains(Substring(String(pid))),
                      let cmd = output("/bin/ps", ["-p", String(pid), "-o", "command="]),
                      !cmd.contains("/Applications/Docker.app/"),
                      !cmd.contains("com.docker.backend")
                else { return false }
                return kill(pid, SIGTERM) == 0
            }
        }.value
    }

    private static func dockerTargets(port: Int) -> [PortConflictTarget] {
        guard let cli = dockerExecutable(),
              let rows = output(cli, ["ps", "--format", "{{.ID}}|{{.Names}}|{{.Ports}}"]) else { return [] }
        return rows.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 3 else { return nil }
            let mappings = parts[2].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard mappings.contains(where: { mapping in
                guard let arrow = mapping.range(of: "->"), let colon = mapping[..<arrow.lowerBound].lastIndex(of: ":") else { return false }
                return Int(mapping[mapping.index(after: colon)..<arrow.lowerBound]) == port
            }) else { return nil }
            return PortConflictTarget(id: "docker-\(parts[0])", kind: .docker,
                title: "Docker — \(parts[1])", detail: "Container \(parts[0]) · host port \(port)",
                pid: nil, birth: nil, containerID: parts[0])
        }
    }

    private static func dockerExecutable() -> String? {
        ["/usr/local/bin/docker", "/opt/homebrew/bin/docker"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private static func output(_ binary: String, _ args: [String], timeout: Int = 5) -> String? {
        guard FileManager.default.isExecutableFile(atPath: binary) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = args
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch { return nil }
    }
}
