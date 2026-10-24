import Foundation
import XCTest
@testable import TrisServerManager

final class HomebrewPostgresServiceTests: XCTestCase {
    func testHomebrewRegistrationDoesNotRequireShellCommand() {
        let entry = ServiceDefinition(
            name: "Local PostgreSQL", kind: .homebrewPostgres,
            workingDirectory: "/tmp/isolated-cluster", command: "",
            port: 5433, group: "Databases"
        )
        XCTAssertNil(entry.validate())
        XCTAssertEqual(entry.kind, .homebrewPostgres)
    }

    func testHomebrewRegistrationRequiresPort() {
        let entry = ServiceDefinition(
            name: "Local PostgreSQL", kind: .homebrewPostgres,
            workingDirectory: "/tmp/isolated-cluster", command: "",
            port: nil, group: "Databases"
        )
        XCTAssertNotNil(entry.validate())
    }

    func testExistingDockerRegistrationStillDecodes() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"DB","kind":"Docker Compose",
         "workingDirectory":"/tmp/example","command":"db","port":5433,"group":"Databases"}
        """
        let entry = try JSONDecoder().decode(ServiceDefinition.self, from: Data(json.utf8))
        XCTAssertEqual(entry.kind, .dockerCompose)
        XCTAssertEqual(entry.command, "db")
    }
}
