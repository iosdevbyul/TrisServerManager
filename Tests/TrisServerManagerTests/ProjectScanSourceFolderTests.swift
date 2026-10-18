import XCTest
@testable import TrisServerManager

final class ProjectScanSourceFolderTests: XCTestCase {
    func testSourceFolderNamedLikeServerIsNotImportedTwice() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let server = root.appendingPathComponent("WakTrainerServer")
        let sources = server.appendingPathComponent("Sources/WakTrainerServer")
        try FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("// Package".utf8).write(to: server.appendingPathComponent("Package.swift"))

        let matches = ProjectDiscovery.scan(root: root, existing: [])
            .filter { $0.definition.name == "WakTrainerServer" }
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.definition.workingDirectory, server.resolvingSymlinksInPath().standardizedFileURL.path)
    }

    func testNestedIndependentPackageIsStillDiscovered() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = root.appendingPathComponent("TrisAuthenticationServer")
        let nested = project.appendingPathComponent("Packages/AuthenticationServerKit")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("// Package".utf8).write(to: project.appendingPathComponent("Package.swift"))
        try Data("// Package".utf8).write(to: nested.appendingPathComponent("Package.swift"))

        let matches = ProjectDiscovery.scan(root: root, existing: [])
        XCTAssertEqual(matches.count, 2)
        XCTAssertTrue(matches.contains { URL(fileURLWithPath: $0.definition.workingDirectory).resolvingSymlinksInPath().standardizedFileURL.path == nested.resolvingSymlinksInPath().standardizedFileURL.path && !$0.isReady })
    }
}
