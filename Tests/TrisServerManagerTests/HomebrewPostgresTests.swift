import Foundation
import XCTest
@testable import TrisServerManager

final class HomebrewPostgresTests: XCTestCase {
    func testRejectsUninitializedCluster() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tris-postgres-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cluster = HomebrewPostgres.Cluster(dataDirectory: directory.path, port: 5433)
        XCTAssertThrowsError(try cluster.validate()) { error in
            XCTAssertEqual(error as? HomebrewPostgres.ConfigurationError, .uninitializedCluster)
        }
        try "16".write(to: directory.appendingPathComponent("PG_VERSION"), atomically: true, encoding: .utf8)
        XCTAssertNoThrow(try cluster.validate())
    }

    func testRejectsInvalidPort() {
        let cluster = HomebrewPostgres.Cluster(dataDirectory: "/tmp/example", port: 0)
        XCTAssertThrowsError(try cluster.validate()) { error in
            XCTAssertEqual(error as? HomebrewPostgres.ConfigurationError, .invalidPort)
        }
    }

    func testCommandsTargetOnlyTheChosenCluster() {
        let cluster = HomebrewPostgres.Cluster(dataDirectory: "/tmp/my postgres", port: 5434)
        let binary = "/opt/homebrew/opt/postgresql@16/bin/pg_ctl"
        XCTAssertEqual(HomebrewPostgres.status(cluster, executable: binary).arguments,
                       ["-D", "/tmp/my postgres", "status"])
        XCTAssertEqual(HomebrewPostgres.start(cluster, executable: binary).arguments,
                       ["-D", "/tmp/my postgres", "-o", "-h 127.0.0.1 -p 5434", "-w", "start"])
        XCTAssertEqual(HomebrewPostgres.stop(cluster, executable: binary).arguments,
                       ["-D", "/tmp/my postgres", "-m", "fast", "-w", "stop"])
    }
}
