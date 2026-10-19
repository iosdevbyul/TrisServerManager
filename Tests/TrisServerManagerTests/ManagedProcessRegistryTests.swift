import XCTest
@testable import TrisServerManager

final class ManagedProcessRegistryTests: XCTestCase {
    func testProcessIdentityRecordRoundTrip() throws {
        let id = UUID()
        let record = ManagedProcessRecord(
            serviceID: id, port: 8080, pid: 1234,
            executable: "/tmp/TrisAuthenticationServer",
            startMarker: "Mon Oct 19 14:00:00 2026")
        let data = try JSONEncoder().encode([id: record])
        let restored = try JSONDecoder().decode([UUID: ManagedProcessRecord].self, from: data)
        XCTAssertEqual(restored[id]?.pid, 1234)
        XCTAssertEqual(restored[id]?.port, 8080)
        XCTAssertEqual(restored[id]?.executable, "/tmp/TrisAuthenticationServer")
    }

    func testNeverTerminatesUnverifiedListener() async {
        let record = ManagedProcessRecord(
            serviceID: UUID(), port: 65534, pid: 1,
            executable: "/bin/launchd", startMarker: "unknown")
        let stopped = await ManagedListener.stopIfMatching(record)
        XCTAssertFalse(stopped)
    }
}
