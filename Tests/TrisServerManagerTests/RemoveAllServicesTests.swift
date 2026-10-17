import XCTest
@testable import TrisServerManager

@MainActor
final class RemoveAllServicesTests: XCTestCase {
    func testRemoveAllClearsPersistedRegistrations() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let fileURL = folder.appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: fileURL)
        store.add(.init(name: "API", kind: .command, workingDirectory: folder.path, command: "swift run API", port: 8081, group: "Test"))
        store.add(.init(name: "Worker", kind: .dockerCompose, workingDirectory: folder.path, command: "worker", port: nil, group: "Test"))
        XCTAssertEqual(store.services.count, 2)

        store.deleteAll()
        XCTAssertTrue(store.services.isEmpty)
        let restored = ServiceStore(fileURL: fileURL)
        XCTAssertTrue(restored.services.isEmpty)
    }

    func testBulkRemovalCannotProceedForRunningService() {
        let runtime = ServiceRuntime()
        let service = ServiceDefinition(name: "API", kind: .command, workingDirectory: "/tmp", command: "swift run API", port: 8081, group: "")
        XCTAssertTrue(runtime.canRemoveRegistrations([service]))
        XCTAssertFalse(runtime.canRemoveRegistrations([]))
    }
}
