import XCTest
@testable import TrisServerManager

final class ProjectDiscoveryTests: XCTestCase {
    func testFindsKnownServerAndSkipsRegisteredFolder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let server = root.appendingPathComponent("WakTrainerServer")
        try FileManager.default.createDirectory(at: server, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("// manifest".utf8).write(to: server.appendingPathComponent("Package.swift"))

        let detected = ProjectDiscovery.scan(root: root, existing: [])
        XCTAssertEqual(detected.count, 1)
        XCTAssertEqual(detected.first?.definition.port, 8081)
        XCTAssertEqual(detected.first?.definition.kind, .command)

        let registered = try XCTUnwrap(detected.first?.definition)
        XCTAssertTrue(ProjectDiscovery.scan(root: root, existing: [registered]).isEmpty)
    }

    func testUnknownSwiftProjectRequiresReview() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = root.appendingPathComponent("ExampleSwift")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("// manifest".utf8).write(to: project.appendingPathComponent("Package.swift"))
        let result = try XCTUnwrap(ProjectDiscovery.scan(root: root, existing: []).first)
        XCTAssertFalse(result.isReady)
        XCTAssertTrue(result.definition.command.isEmpty)
    }
}
