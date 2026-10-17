import Foundation

struct ComposeServiceCandidate: Identifiable, Hashable {
    var id: String { name }
    let name: String
}

enum ComposeServiceDiscovery {
    static func discover(in directory: URL) async throws -> [ComposeServiceCandidate] {
        let path = directory.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw RuntimeFailure("Select an existing Docker Compose directory.")
        }

        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["docker", "compose", "config", "--services"]
            process.currentDirectoryURL = directory
            var environment = ProcessInfo.processInfo.environment
            environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
            process.environment = environment

            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
                throw RuntimeFailure("Unable to create temporary output file.")
            }
            defer { try? FileManager.default.removeItem(at: outputURL) }
            let outputHandle = try FileHandle(forWritingTo: outputURL)
            process.standardOutput = outputHandle
            process.standardError = outputHandle
            do {
                try process.run()
                process.waitUntilExit()
                try outputHandle.close()
            } catch {
                try? outputHandle.close()
                throw error
            }

            let output = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
            guard process.terminationStatus == 0 else {
                throw RuntimeFailure(output.isEmpty ? "Docker Compose discovery failed." : output)
            }
            let names = Set(output.split(whereSeparator: \.isNewline).map(String.init))
            return names.sorted().map { ComposeServiceCandidate(name: $0) }
        }.value
    }
}
