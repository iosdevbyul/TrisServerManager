import XCTest
@testable import TrisServerManager

final class LocalProjectDetectorTests: XCTestCase {
    func testSuggestsOnlyDeclaredNodeScripts() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try Data(#"{"scripts":{"dev":"next dev","test":"vitest"}}"#.utf8)
            .write(to: folder.appendingPathComponent("package.json"))
        let suggestions = LocalProjectDetector.suggestions(in: folder)
        XCTAssertEqual(suggestions.map(\.command), ["npm run dev"])
    }

    func testSwiftSuggestionRequiresManifest() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertTrue(LocalProjectDetector.suggestions(in: folder).isEmpty)
        try Data("// swift package".utf8).write(to: folder.appendingPathComponent("Package.swift"))
        XCTAssertTrue(LocalProjectDetector.suggestions(in: folder).contains { $0.command == "swift run" })
    }
}
