import Foundation

enum RuntimeDiagnostics {
    /// Returns true when a process currently holds a listening TCP socket on the given port.
    /// A missing lsof binary or an unexpected exit is reported as an error, not an unused port.
    static func isPortInUse(_ port: Int) async throws -> Bool {
        guard (1...65535).contains(port) else {
            throw RuntimeFailure("Invalid TCP port: \(port)")
        }
        return try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
            process.arguments = ["-nP", "-iTCP:\(port)", "-sTCP:LISTEN"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            switch process.terminationStatus {
            case 0: return true
            case 1: return false
            default: throw RuntimeFailure("Port inspection failed (exit \(process.terminationStatus)).")
            }
        }.value
    }
}
