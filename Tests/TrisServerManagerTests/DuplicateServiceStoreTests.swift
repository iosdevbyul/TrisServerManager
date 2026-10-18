import XCTest
@testable import TrisServerManager

@MainActor
final class DuplicateServiceStoreTests: XCTestCase {
    func testAllowsDifferentCommandsButRejectsExactDuplicate() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let registry = root.appendingPathComponent("services.json")
        let store = ServiceStore(fileURL: registry)
        let first = ServiceDefinition(name: "A", kind: .command, workingDirectory: root.path, command: "swift run", port: 8081, group: "")
        store.add(first)
        var duplicate = first
        duplicate.id = UUID()
        duplicate.command = "swift run Other"
        store.add(duplicate)
        XCTAssertEqual(store.services.count, 2)
        var identical = first
        identical.id = UUID()
        store.add(identical)
        XCTAssertEqual(store.services.count, 2)
        XCTAssertNotNil(store.errorMessage)
    }

    func testComposeServicesInSameDirectoryCanCoexist() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ServiceStore(fileURL: root.appendingPathComponent("services.json"))
        store.add(.init(name: "db", kind: .dockerCompose, workingDirectory: root.path, command: "db", port: nil, group: ""))
        store.add(.init(name: "api", kind: .dockerCompose, workingDirectory: root.path, command: "api", port: nil, group: ""))
        XCTAssertEqual(store.services.count, 2)
    }
}
