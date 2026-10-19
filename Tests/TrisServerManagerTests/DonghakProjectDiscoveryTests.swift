import XCTest
@testable import TrisServerManager

final class DonghakProjectDiscoveryTests: XCTestCase {
    func testVerifiedDonghakAPIIsImportable() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = root.appendingPathComponent("DonghakStockVision")
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".venv/bin"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project.appendingPathComponent(".data"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("[project.scripts]\ndsv-api = \"donghak_stock_vision.api_cli:main\"".utf8).write(to: project.appendingPathComponent("pyproject.toml"))
        let binary = project.appendingPathComponent(".venv/bin/dsv-api")
        try Data("#!/bin/sh\n".utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        try Data("{}".utf8).write(to: project.appendingPathComponent(".data/research-api-snapshot.json"))
        let found = ProjectDiscovery.scan(root: root, existing: [])
        let entry = try XCTUnwrap(found.first { $0.definition.name == "DonghakStockVision API" })
        XCTAssertTrue(entry.isReady)
        XCTAssertEqual(entry.definition.command, ".venv/bin/dsv-api --snapshot .data/research-api-snapshot.json")
        XCTAssertEqual(entry.definition.port, 8000)
        XCTAssertEqual(entry.definition.healthCheckPath, "/api/v1/health")
    }

    func testMissingSnapshotBlocksAutomaticImport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = root.appendingPathComponent("DonghakStockVision")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("[project.scripts]\ndsv-api = \"donghak_stock_vision.api_cli:main\"".utf8).write(to: project.appendingPathComponent("pyproject.toml"))
        let found = ProjectDiscovery.scan(root: root, existing: [])
        let entry = try XCTUnwrap(found.first { $0.definition.name == "DonghakStockVision API" })
        XCTAssertFalse(entry.isReady)
        XCTAssertTrue(entry.definition.command.isEmpty)
    }
}
