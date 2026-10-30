import XCTest
@testable import TrisServerManager

final class DevelopmentServicePresetTests: XCTestCase {
    func testAllPresetsRequireUserSelectedFolder() {
        XCTAssertEqual(DevelopmentServicePreset.known.count, 5)
        for preset in DevelopmentServicePreset.known {
            XCTAssertTrue(preset.draft().workingDirectory.isEmpty)
            XCTAssertNotNil(preset.draft().validate())
        }
    }

    func testUnknownDonghakLaunchCommandIsNotInvented() {
        let preset = try! XCTUnwrap(DevelopmentServicePreset.known.first { $0.id == "donghak" })
        XCTAssertTrue(preset.command.isEmpty)
        XCTAssertNil(preset.port)
    }

    func testMarketLensDoesNotAssumeAvailablePort3000() {
        let preset = try! XCTUnwrap(DevelopmentServicePreset.known.first { $0.id == "marketlens" })
        XCTAssertEqual(preset.command, "npm run dev")
        XCTAssertNil(preset.port)
    }

    func testRewardLedgerUsesLocalPythonWithoutDocker() {
        let preset = try! XCTUnwrap(DevelopmentServicePreset.known.first { $0.id == "reward-ledger" })
        XCTAssertEqual(preset.command, "python3 server/app.py")
        XCTAssertEqual(preset.port, 8765)
        XCTAssertEqual(preset.draft().kind, .command)
        XCTAssertEqual(preset.group, "TrisAdKit")
    }

    func testSwiftServerPresetsHaveExplicitPorts() {
        XCTAssertEqual(DevelopmentServicePreset.known.first { $0.id == "waktrainer" }?.port, 8081)
        XCTAssertEqual(DevelopmentServicePreset.known.first { $0.id == "authentication" }?.port, 8080)
    }
}
