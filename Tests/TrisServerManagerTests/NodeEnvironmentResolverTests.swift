import XCTest
@testable import TrisServerManager

final class NodeEnvironmentResolverTests: XCTestCase {
    func testNpmLaunchIncludesNvmRecoveryAndVisibleDiagnostics() {
        let script = NodeEnvironmentResolver.wrap("npm run dev")
        XCTAssertTrue(script.contains("nvm.sh"))
        XCTAssertTrue(script.contains("nvm use --silent node"))
        XCTAssertTrue(script.contains("Project .nvmrc found"))
        XCTAssertTrue(script.contains("[Environment] Effective Node.js"))
        XCTAssertTrue(script.hasSuffix("exec npm run dev"))
    }

    func testSwiftLaunchIsNotModified() {
        let command = "swift run WakTrainerServer serve --hostname 127.0.0.1 --port 8081"
        XCTAssertEqual(NodeEnvironmentResolver.wrap(command), "exec " + command)
    }
}
