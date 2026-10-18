import Foundation
import Observation

enum ServiceRuntimeStatus: String {
    case stopped = "Stopped"
    case starting = "Starting"
    case running = "Running"
    case stopping = "Stopping"
    case failed = "Failed"
    case unknown = "Unknown"
    case portInUse = "Port In Use"
}

@MainActor
@Observable
final class ServiceRuntime {
    private(set) var statuses: [UUID: ServiceRuntimeStatus] = [:]
    private(set) var logs: [UUID: String] = [:]
    var errorMessage: String?

    @ObservationIgnored private var processes: [UUID: Process] = [:]
    @ObservationIgnored private var busy: Set<UUID> = []
    @ObservationIgnored private var logRequests: Set<UUID> = []
    @ObservationIgnored private var readinessTasks: [UUID: Task<Void, Never>] = [:]

    func status(for service: ServiceDefinition) -> ServiceRuntimeStatus {
        statuses[service.id] ?? .unknown
    }

    func ownsRunningProcess(_ id: UUID) -> Bool { processes[id]?.isRunning == true }

    func log(for id: UUID) -> String { logs[id] ?? "No output yet." }

    func start(_ service: ServiceDefinition) async {
        guard !busy.contains(service.id) else { return }
        if status(for: service) == .running { return }
        busy.insert(service.id)
        statuses[service.id] = .starting
        defer { busy.remove(service.id) }

        if service.kind == .dockerCompose {
            do {
                let output = try await docker(["compose", "up", "-d", service.command], in: service.workingDirectory)
                append(output, to: service.id)
                statuses[service.id] = .running
            } catch { fail(error, for: service.id) }
            return
        }

        guard FileManager.default.fileExists(atPath: service.workingDirectory) else {
            fail(RuntimeFailure("Working directory does not exist."), for: service.id)
            return
        }

        if let port = service.port {
            do {
                if try await RuntimeDiagnostics.isPortInUse(port) {
                    fail(RuntimeFailure("Port \(port) is already in use."), for: service.id)
                    return
                }
            } catch {
                fail(error, for: service.id)
                return
            }
        }
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", NodeEnvironmentResolver.wrap(service.command)]
        process.currentDirectoryURL = URL(fileURLWithPath: service.workingDirectory)
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.append(output, to: service.id) }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.append(output, to: service.id) }
        }

        process.terminationHandler = { [weak self] finished in
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                guard let self, self.processes[service.id] === finished else { return }
                self.readinessTasks[service.id]?.cancel()
                self.readinessTasks[service.id] = nil
                self.processes[service.id] = nil
                self.statuses[service.id] = (finished.terminationStatus == 0 || (finished.terminationReason == .uncaughtSignal && finished.terminationStatus == 15)) ? .stopped : .failed
                self.append("Process exited with status \\(finished.terminationStatus).\\n", to: service.id)
            }
        }
        do {
            try process.run()
            processes[service.id] = process
            if let port = service.port {
                readinessTasks[service.id]?.cancel()
                readinessTasks[service.id] = Task { [weak self] in
                    guard let self else { return }
                    for _ in 0..<60 {
                        guard !Task.isCancelled, self.processes[service.id] === process, process.isRunning else { return }
                        if (try? await RuntimeDiagnostics.isPortInUse(port)) == true {
                            guard !Task.isCancelled, self.processes[service.id] === process else { return }
                            self.statuses[service.id] = .running
                            self.readinessTasks[service.id] = nil
                            return
                        }
                        do { try await Task.sleep(for: .milliseconds(500)) }
                        catch { return }
                    }
                    guard !Task.isCancelled, self.processes[service.id] === process, process.isRunning else { return }
                    self.statuses[service.id] = .unknown
                    self.append("Readiness unverified after 30 seconds. Process still running; check configured port.\n", to: service.id)
                    self.readinessTasks[service.id] = nil
                }
            } else {
                statuses[service.id] = .unknown
                append("Process launched but no port is configured; readiness is unverified.\n", to: service.id)
            }
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            fail(error, for: service.id)
        }
    }

    func stop(_ service: ServiceDefinition) async {
        guard !busy.contains(service.id) else { return }
        busy.insert(service.id)
        statuses[service.id] = .stopping
        defer { busy.remove(service.id) }

        if service.kind == .dockerCompose {
            do {
                let output = try await docker(["compose", "stop", service.command], in: service.workingDirectory)
                append(output, to: service.id)
                statuses[service.id] = .stopped
            } catch { fail(error, for: service.id) }
            return
        }
        guard let process = processes[service.id] else {
            statuses[service.id] = .unknown
            errorMessage = "This local process was not started by the app in this session."
            return
        }
        guard process.isRunning else {
            statuses[service.id] = .stopped
            return
        }
        readinessTasks[service.id]?.cancel()
        readinessTasks[service.id] = nil
        process.terminate()
        // State is reconciled by terminationHandler. Never kill an unrelated PID.
    }

    func startAll(_ services: [ServiceDefinition]) async {
        // Docker dependencies first, while preserving the user's relative order
        // within each category. Compose up -d does not guarantee DB readiness.
        let dockerServices = services.filter { $0.kind == .dockerCompose }
        let localServices = services.filter { $0.kind == .command }
        for service in dockerServices { await start(service) }
        for service in localServices { await start(service) }
    }

    func stopAll(_ services: [ServiceDefinition]) async {
        // Stop local API processes before their Docker dependencies.
        let localServices = services.filter { $0.kind == .command }
        let dockerServices = services.filter { $0.kind == .dockerCompose }
        for service in localServices.reversed() where processes[service.id] != nil {
            await stop(service)
        }
        for service in dockerServices.reversed() { await stop(service) }
    }

    func stopOwnedLocalProcesses() {
        // Only touch Process instances started by this app session.
        // This is called by macOS when the app terminates.
        for task in readinessTasks.values { task.cancel() }
        readinessTasks.removeAll()
        for process in processes.values where process.isRunning {
            process.terminate()
        }
    }

    func refresh(_ service: ServiceDefinition) async {
        guard !busy.contains(service.id) else { return }
        if service.kind == .command {
            if let process = processes[service.id], process.isRunning {
                if readinessTasks[service.id] != nil { return }
                guard let port = service.port else { statuses[service.id] = .unknown; return }
                do {
                    statuses[service.id] = try await RuntimeDiagnostics.isPortInUse(port) ? .running : .unknown
                } catch { statuses[service.id] = .unknown }
            } else if let port = service.port {
                do {
                    statuses[service.id] = try await RuntimeDiagnostics.isPortInUse(port) ? .portInUse : .stopped
                } catch {
                    statuses[service.id] = .unknown
                }
            } else {
                statuses[service.id] = .unknown
            }
            return
        }
        do {
            let output = try await docker(["compose", "ps", "--status", "running", "--services"], in: service.workingDirectory)
            let names = Set(output.split(whereSeparator: \.isNewline).map(String.init))
            statuses[service.id] = names.contains(service.command) ? .running : .stopped
        } catch { statuses[service.id] = .unknown }
    }

    func loadDockerLogs(_ service: ServiceDefinition) async {
        guard service.kind == .dockerCompose, !busy.contains(service.id), !logRequests.contains(service.id) else { return }
        logRequests.insert(service.id)
        defer { logRequests.remove(service.id) }
        do {
            let output = try await docker(["compose", "logs", "--no-color", "--tail", "200", service.command], in: service.workingDirectory)
            logs[service.id] = String(output.suffix(50_000))
        } catch {
            append("Could not refresh Docker logs: \(error.localizedDescription)\n", to: service.id)
        }
    }

    func refreshAll(_ services: [ServiceDefinition]) async {
        for service in services { await refresh(service) }
    }

    func canRemoveRegistrations(_ services: [ServiceDefinition]) -> Bool {
        !services.isEmpty && services.allSatisfy { service in
            !busy.contains(service.id) &&
            processes[service.id] == nil &&
            ![ServiceRuntimeStatus.running, .starting, .stopping].contains(status(for: service))
        }
    }

    func forget(_ id: UUID) {
        // A running process retains its registration until stopped; do not discard its handle.
        if processes[id] == nil {
            statuses[id] = nil
            logs[id] = nil
        }
    }

    private func append(_ text: String, to id: UUID) {
        let combined = (logs[id] ?? "") + text
        logs[id] = String(combined.suffix(50_000))
    }

    private func fail(_ error: Error, for id: UUID) {
        statuses[id] = .failed
        errorMessage = error.localizedDescription
        append("ERROR: \\(error.localizedDescription)\\n", to: id)
    }

    private nonisolated func docker(_ args: [String], in directory: String) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["docker"] + args
            process.currentDirectoryURL = URL(fileURLWithPath: directory)
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
            process.environment = environment
            let outputFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            FileManager.default.createFile(atPath: outputFile.path, contents: nil)
            defer { try? FileManager.default.removeItem(at: outputFile) }
            let handle = try FileHandle(forWritingTo: outputFile)
            process.standardOutput = handle
            process.standardError = handle
            try process.run()
            process.waitUntilExit()
            try? handle.close()
            let output = (try? String(contentsOf: outputFile, encoding: .utf8)) ?? ""
            guard process.terminationStatus == 0 else {
                throw RuntimeFailure(output.isEmpty ? "Docker command failed." : output)
            }
            return output
        }.value
    }
}

struct RuntimeFailure: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
