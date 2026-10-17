import XCTest
@testable import TrisServerManager

@MainActor
final class ServiceStoreTests: XCTestCase {
    func testAddUpdateDeleteAndReload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("services.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = ServiceStore(fileURL: url)
        var service = ServiceDefinition(name: "API", kind: .command, workingDirectory: "/tmp", command: "swift run", port: 8080, group: "Tests")
        store.add(service)
        XCTAssertEqual(store.services.count, 1)
        service.name = "Updated API"
        store.update(service)
        XCTAssertEqual(ServiceStore(fileURL: url).services.first?.name, "Updated API")
        store.delete(service.id)
        XCTAssertTrue(ServiceStore(fileURL: url).services.isEmpty)
    }

    func testInvalidServiceIsNotAdded() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: url)
        store.add(ServiceDefinition(name: "", kind: .command, workingDirectory: "/tmp", command: "pwd", port: nil, group: ""))
        XCTAssertTrue(store.services.isEmpty)
        XCTAssertNotNil(store.errorMessage)
    }
}
