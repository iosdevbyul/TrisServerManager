import Foundation
import Darwin

/// Port ownership recovery is deliberately limited to exact previously recorded
/// listener PIDs. A same-named executable alone is never sufficient.
enum ManagedListener {
    static func inspect(port: Int) async -> (pid: Int32, executable: String, startMarker: String)? {
        await Task.detached(priority: .utility) {
            guard (1...65535).contains(port) else { return nil }
            guard let pids = run("/usr/sbin/lsof", ["-nP", "-t", "-iTCP:\(port)", "-sTCP:LISTEN"]),
                  let pidString = pids.split(whereSeparator: \.isNewline).onlyElement,
                  let pid = Int32(pidString), pid > 1,
                  let owner = run("/bin/ps", ["-p", String(pid), "-o", "uid="]),
                  UInt32(owner.trimmingCharacters(in: .whitespacesAndNewlines)) == getuid(),
                  let command = run("/bin/ps", ["-p", String(pid), "-o", "comm="]),
                  let started = run("/bin/ps", ["-p", String(pid), "-o", "lstart="]) else { return nil }
            return (pid, command.trimmingCharacters(in: .whitespacesAndNewlines),
                    started.trimmingCharacters(in: .whitespacesAndNewlines))
        }.value
    }

    static func stopIfMatching(_ record: ManagedProcessRecord) async -> Bool {
        guard let now = await inspect(port: record.port),
              now.pid == record.pid,
              now.executable == record.executable,
              now.startMarker == record.startMarker else { return false }
        return await Task.detached(priority: .utility) {
            // Never use kill -9. Recheck the birth marker immediately before signaling.
            guard let started = run("/bin/ps", ["-p", String(record.pid), "-o", "lstart="]),
                  started.trimmingCharacters(in: .whitespacesAndNewlines) == record.startMarker
            else { return false }
            guard kill(record.pid, SIGTERM) == 0 else { return false }
            for _ in 0..<30 {
                if kill(record.pid, 0) != 0 { return true }
                usleep(100_000)
            }
            return false
        }.value
    }

    /// Recover an existing Next.js listener only when its PID, ownership,
    /// exact working directory and Next executable identity all agree.
    /// Port alone is never evidence of a same-project service.
    static func stopSameProjectNextListener(port: Int, directory: String) async -> Bool {
        guard let observed = await inspect(port: port) else { return false }
        return await Task.detached(priority: .utility) {
            let pid = observed.pid
            guard let cwdOutput = run("/usr/sbin/lsof", ["-a", "-p", String(pid), "-d", "cwd", "-Fn"]),
                  let cwd = cwdOutput.split(whereSeparator: \.isNewline)
                    .first(where: { $0.hasPrefix("n/") }).map({ String($0.dropFirst()) }),
                  URL(fileURLWithPath: cwd).standardizedFileURL.resolvingSymlinksInPath().path ==
                  URL(fileURLWithPath: directory).standardizedFileURL.resolvingSymlinksInPath().path,
                  let args = run("/bin/ps", ["-p", String(pid), "-o", "command="]),
                  // A node executable named next-server is the actual Next.js dev listener.
                  (args.contains("next-server") || args.contains("next/dist/bin/next")),
                  let started = run("/bin/ps", ["-p", String(pid), "-o", "lstart="]),
                  started.trimmingCharacters(in: .whitespacesAndNewlines) == observed.startMarker,
                  let currentOwner = run("/bin/ps", ["-p", String(pid), "-o", "uid="]),
                  UInt32(currentOwner.trimmingCharacters(in: .whitespacesAndNewlines)) == getuid()
            else { return false }

            guard kill(pid, SIGTERM) == 0 else { return false }
            for _ in 0..<30 {
                if kill(pid, 0) != 0 { return true }
                usleep(100_000)
            }
            return false
        }.value
    }

    private static func run(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch { return nil }
    }
}

private extension Collection {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
