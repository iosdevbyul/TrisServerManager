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

    func testDetectsReadyTrisDashboardWithValidatedLaunchAndHealth() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = root.appendingPathComponent("TrisDashboard")
        let backend = project.appendingPathComponent("backend")
        let bin = project.appendingPathComponent(".venv/bin")
        try FileManager.default.createDirectory(at: backend, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("fastapi".utf8).write(to: project.appendingPathComponent("requirements.txt"))
        try Data("from fastapi import FastAPI\\napp = FastAPI()".utf8).write(
            to: backend.appendingPathComponent("app.py"))
        let python = bin.appendingPathComponent("python")
        try Data("#!/bin/sh\\nexit 0\\n".utf8).write(to: python)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: python.path)

        let detected = ProjectDiscovery.scan(root: root, existing: [])
        let service = try XCTUnwrap(detected.first)
        XCTAssertEqual(detected.count, 1)
        XCTAssertTrue(service.isReady)
        XCTAssertEqual(service.definition.name, "TrisDashboard")
        XCTAssertEqual(service.definition.workingDirectory, project.path)
        XCTAssertEqual(service.definition.command,
                       ".venv/bin/python -m uvicorn backend.app:app --host 0.0.0.0 --port 8080")
        XCTAssertEqual(service.definition.port, 8080)
        XCTAssertEqual(service.definition.healthCheckPath, "/healthz")
        XCTAssertEqual(service.definition.group, "TrisDashboard")
        XCTAssertNil(service.definition.validate())
        XCTAssertTrue(ProjectDiscovery.scan(root: root, existing: [service.definition]).isEmpty)

        let directScan = ProjectDiscovery.scan(root: project, existing: [])
        XCTAssertEqual(directScan.count, 1)
        XCTAssertTrue(directScan[0].isReady)
        XCTAssertEqual(directScan[0].definition.healthCheckPath, "/healthz")
    }

    func testTrisDashboardWithoutEnvironmentRequiresReview() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = root.appendingPathComponent("TrisDashboard")
        try FileManager.default.createDirectory(at: project.appendingPathComponent("backend"),
                                                withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("fastapi".utf8).write(to: project.appendingPathComponent("requirements.txt"))
        try Data("app = FastAPI()".utf8).write(to: project.appendingPathComponent("backend/app.py"))

        let detected = try XCTUnwrap(ProjectDiscovery.scan(root: root, existing: []).first)
        XCTAssertFalse(detected.isReady)
        XCTAssertEqual(detected.definition.command, "")
        XCTAssertEqual(detected.definition.port, 8080)
        XCTAssertEqual(detected.definition.healthCheckPath, "/healthz")
        XCTAssertNotNil(detected.definition.validate())
        XCTAssertTrue(detected.note.contains(".venv/bin/python"))
    }

    func testTrisDashboardNameAloneDoesNotProduceReadyCommand() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = root.appendingPathComponent("TrisDashboard")
        let bin = project.appendingPathComponent(".venv/bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("fastapi".utf8).write(to: project.appendingPathComponent("requirements.txt"))
        let python = bin.appendingPathComponent("python")
        try Data("#!/bin/sh\\nexit 0\\n".utf8).write(to: python)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: python.path)

        let detected = try XCTUnwrap(ProjectDiscovery.scan(root: root, existing: []).first)
        XCTAssertFalse(detected.isReady)
        XCTAssertTrue(detected.definition.command.isEmpty)
        XCTAssertNil(detected.definition.port)
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
